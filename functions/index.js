const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const PRICECHARTING_TOKEN = defineSecret("PRICECHARTING_TOKEN");

const CACHE_COLLECTION = "liveGradedPriceCache";
const CACHE_TTL_WITH_PRICES_MS = 12 * 60 * 60 * 1000;
const CACHE_TTL_EMPTY_MS = 20 * 60 * 1000;
let lastExternalLookupAt = 0;

function normalizeText(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function uniqueStrings(values) {
  const seen = new Set();
  const output = [];
  for (const value of values) {
    const cleaned = String(value || "").replace(/\s+/g, " ").trim();
    if (!cleaned) continue;
    const key = cleaned.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    output.push(cleaned);
  }
  return output;
}

function buildSetVariants(setName) {
  const cleanSet = String(setName || "").trim();
  if (!cleanSet) return [];
  return uniqueStrings([
    cleanSet,
    cleanSet.replace(/black star promos?/gi, "promo"),
    cleanSet.replace(/pokemon\s+/gi, ""),
    cleanSet.replace(/scarlet\s*&\s*violet/gi, "SV"),
    cleanSet.replace(/sword\s*&\s*shield/gi, "SWSH"),
  ]);
}

function buildQueryCandidates({ name, setName, number }) {
  const cleanName = String(name || "").trim();
  const cleanNumber = String(number || "").trim();
  const numberDigits = cleanNumber.replace(/[^0-9]+/g, "");
  const numberNoLeadingZeros = numberDigits.replace(/^0+/, "") || numberDigits;
  const setVariants = buildSetVariants(setName);

  const candidates = [];
  for (const setVariant of setVariants) {
    candidates.push(`${cleanName} ${setVariant} ${cleanNumber} pokemon card`);
    candidates.push(`${cleanName} ${setVariant} pokemon card`);
    if (numberDigits) {
      candidates.push(`${cleanName} ${setVariant} ${numberDigits} pokemon card`);
    }
    if (numberNoLeadingZeros && numberNoLeadingZeros !== numberDigits) {
      candidates.push(`${cleanName} ${setVariant} ${numberNoLeadingZeros} pokemon card`);
    }
  }

  candidates.push(`${cleanName} ${cleanNumber} pokemon card`);
  if (numberDigits) candidates.push(`${cleanName} ${numberDigits} pokemon card`);
  if (numberNoLeadingZeros && numberNoLeadingZeros !== numberDigits) {
    candidates.push(`${cleanName} ${numberNoLeadingZeros} pokemon card`);
  }
  candidates.push(`${cleanName} pokemon card`);

  return uniqueStrings(candidates).slice(0, 10);
}

function centsToDollars(value) {
  const raw = typeof value === "string" ? Number(value) : value;
  if (typeof raw !== "number" || !Number.isFinite(raw) || raw <= 0) {
    return null;
  }
  return Number((raw / 100).toFixed(2));
}

function addPrice(target, label, rawCents) {
  const value = centsToDollars(rawCents);
  if (value != null) {
    target[label] = value;
  }
}

function extractPrices(product) {
  const prices = {};
  addPrice(prices, "PSA 10", product["manual-only-price"]);
  addPrice(prices, "BGS 10", product["bgs-10-price"]);
  addPrice(prices, "CGC 10", product["condition-17-price"]);
  addPrice(prices, "SGC 10", product["condition-18-price"]);
  addPrice(prices, "Graded 9", product["graded-price"]);
  addPrice(prices, "BGS 9.5", product["box-only-price"]);
  addPrice(prices, "Graded 8/8.5", product["new-price"]);
  return prices;
}

function numericPriceSummary(product) {
  return {
    ungraded: centsToDollars(product["loose-price"]),
    grade7: centsToDollars(product["cib-price"]),
    grade8: centsToDollars(product["new-price"]),
    grade9: centsToDollars(product["graded-price"]),
    grade95: centsToDollars(product["box-only-price"]),
    psa10: centsToDollars(product["manual-only-price"]),
    bgs10: centsToDollars(product["bgs-10-price"]),
    cgc10: centsToDollars(product["condition-17-price"]),
    sgc10: centsToDollars(product["condition-18-price"]),
  };
}

function looksLikeCardMatch(product, card) {
  const productName = normalizeText(product["product-name"]);
  const consoleName = normalizeText(product["console-name"]);
  const genre = normalizeText(product["genre"]);
  const cardName = normalizeText(card.name);
  const cardSet = normalizeText(card.setName);
  const cardNumber = normalizeText(card.number);
  const numberDigits = cardNumber.replace(/[^0-9]+/g, "");

  const pokemonSignals = [
    consoleName.includes("pokemon"),
    consoleName.includes("card"),
    genre.includes("pokemon"),
    genre.includes("card"),
    productName.includes("pokemon"),
  ].filter(Boolean).length;

  if (cardName && !productName.includes(cardName)) {
    return false;
  }

  if (numberDigits && !productName.includes(numberDigits)) {
    if (cardSet && !productName.includes(cardSet)) {
      return false;
    }
  }

  return pokemonSignals > 0 || (cardSet && productName.includes(cardSet));
}

function scoreProduct(product, card) {
  const productName = normalizeText(product["product-name"]);
  const consoleName = normalizeText(product["console-name"]);
  const genre = normalizeText(product["genre"]);
  const cardName = normalizeText(card.name);
  const cardSet = normalizeText(card.setName);
  const numberDigits = normalizeText(card.number).replace(/[^0-9]+/g, "");
  const prices = extractPrices(product);

  let score = 0;
  if (productName.includes(cardName)) score += 40;
  if (cardSet && productName.includes(cardSet)) score += 20;
  if (numberDigits && productName.includes(numberDigits)) score += 15;
  if (consoleName.includes("pokemon")) score += 10;
  if (genre.includes("pokemon")) score += 10;
  if (Object.keys(prices).length > 0) score += 25;
  if (prices["PSA 10"] != null) score += 15;
  if (prices["BGS 10"] != null) score += 10;
  if (prices["CGC 10"] != null || prices["SGC 10"] != null) score += 8;
  return score;
}

async function waitForPriceChartingWindow() {
  const now = Date.now();
  const waitMs = Math.max(0, 1100 - (now - lastExternalLookupAt));
  if (waitMs > 0) {
    await new Promise((resolve) => setTimeout(resolve, waitMs));
  }
  lastExternalLookupAt = Date.now();
}

async function fetchBestProduct({ token, query }) {
  await waitForPriceChartingWindow();

  const url = new URL("https://www.pricecharting.com/api/product");
  url.searchParams.set("t", token);
  url.searchParams.set("q", query);

  const response = await fetch(url.toString(), {
    method: "GET",
    headers: {
      accept: "application/json",
      "user-agent": "pokemon-hub-live-graded-prices/1.1",
    },
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok || data.status === "error") {
    const message =
      data["error-message"] ||
      `PriceCharting request failed with HTTP ${response.status}`;
    throw new Error(message);
  }

  return data;
}

exports.getLiveGradedPrices = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 45,
    memory: "256MiB",
    maxInstances: 1,
    concurrency: 1,
    secrets: [PRICECHARTING_TOKEN],
  },
  async (request) => {
    const data = request.data || {};
    const card = {
      cardId: String(data.cardId || "").trim(),
      name: String(data.name || "").trim(),
      setName: String(data.setName || "").trim(),
      number: String(data.number || "").trim(),
    };

    if (!card.name) {
      throw new HttpsError(
        "invalid-argument",
        "Card name is required for graded price lookups.",
      );
    }

    const cacheKey =
      card.cardId ||
      normalizeText(`${card.name} ${card.setName} ${card.number}`).slice(0, 120);

    const cacheRef = db.collection(CACHE_COLLECTION).doc(cacheKey);
    const now = Date.now();
    const cacheSnap = await cacheRef.get();

    if (cacheSnap.exists) {
      const cached = cacheSnap.data() || {};
      const fetchedAtMs = Number(cached.fetchedAtMs || 0);
      const cachedPrices = cached.prices || {};
      const hasPrices = Object.keys(cachedPrices).length > 0;
      const ttl = hasPrices ? CACHE_TTL_WITH_PRICES_MS : CACHE_TTL_EMPTY_MS;

      if (fetchedAtMs > 0 && now - fetchedAtMs < ttl) {
        logger.info("Returning cached graded prices", {
          card,
          cacheKey,
          hasPrices,
          matchedProductName: cached.matchedProductName || null,
          query: cached.query || null,
        });
        return {
          prices: cachedPrices,
          currencyCode: cached.currencyCode || "USD",
          matchedProductName: cached.matchedProductName || null,
          query: cached.query || null,
          fetchedAt: new Date(fetchedAtMs).toISOString(),
          source: "cache",
          productId: cached.productId || null,
        };
      }
    }

    const token = PRICECHARTING_TOKEN.value();
    if (!token) {
      throw new HttpsError(
        "failed-precondition",
        "PRICECHARTING_TOKEN secret is missing.",
      );
    }

    const queries = buildQueryCandidates(card);
    logger.info("Starting PriceCharting lookup", { card, queries });

    let bestCandidate = null;

    for (const query of queries) {
      try {
        const product = await fetchBestProduct({ token, query });
        const prices = extractPrices(product);
        const summary = numericPriceSummary(product);
        const match = looksLikeCardMatch(product, card);
        const score = scoreProduct(product, card);
        const candidate = {
          product,
          prices,
          query,
          match,
          score,
        };

        logger.info("PriceCharting candidate", {
          query,
          matchedProductName: product["product-name"] || null,
          consoleName: product["console-name"] || null,
          genre: product["genre"] || null,
          score,
          match,
          summary,
        });

        if (!bestCandidate || candidate.score > bestCandidate.score) {
          bestCandidate = candidate;
        }

        if (match && Object.keys(prices).length > 0) {
          bestCandidate = candidate;
          break;
        }
      } catch (error) {
        logger.error("PriceCharting lookup failed for query", {
          query,
          message: error instanceof Error ? error.message : String(error),
        });
      }
    }

    if (!bestCandidate || !bestCandidate.product) {
      throw new HttpsError(
        "not-found",
        "No matching graded price listing was found.",
      );
    }

    const matched = bestCandidate.product;
    const prices = bestCandidate.prices || {};
    const payload = {
      prices,
      currencyCode: "USD",
      matchedProductName: matched["product-name"] || null,
      query: bestCandidate.query,
      fetchedAtMs: now,
      productId: matched.id || null,
    };

    await cacheRef.set(payload, { merge: true });

    logger.info("Selected PriceCharting result", {
      card,
      query: bestCandidate.query,
      matchedProductName: payload.matchedProductName,
      productId: payload.productId,
      score: bestCandidate.score,
      prices,
      numericPriceSummary: numericPriceSummary(matched),
    });

    return {
      prices,
      currencyCode: "USD",
      matchedProductName: payload.matchedProductName,
      query: bestCandidate.query,
      fetchedAt: new Date(now).toISOString(),
      source: "pricecharting",
      productId: payload.productId,
    };
  },
);