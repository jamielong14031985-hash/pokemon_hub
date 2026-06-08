// PocketChase external Pokémon card pricing fallback.
// Uses JustTCG through Firebase Cloud Functions v2 + Secret Manager.
// Designed to avoid Free Tier rate limits by doing fewer provider calls and
// caching successful and unsuccessful lookups in Firestore.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const JUSTTCG_API_KEY = defineSecret('JUSTTCG_API_KEY');
const JUSTTCG_BASE_URL = 'https://api.justtcg.com/v1/cards';
const CACHE_COLLECTION = 'external_card_price_cache';

const SUCCESS_CACHE_MS = 24 * 60 * 60 * 1000;
const NO_MATCH_CACHE_MS = 6 * 60 * 60 * 1000;
const RATE_LIMIT_CACHE_MS = 2 * 60 * 1000;

function clean(value) {
  return String(value || '').trim();
}

function normalise(value) {
  return clean(value)
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function compact(value) {
  return normalise(value).replace(/\s+/g, '');
}

function normaliseCardNumber(value) {
  const raw = clean(value).toLowerCase();
  if (!raw) return '';

  const firstPart = raw.split('/')[0] || raw;
  const stripped = firstPart.replace(/[^a-z0-9]+/g, '');
  return stripped.replace(/^0+(\d)/, '$1');
}

function safeCacheId(value) {
  return clean(value)
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .substring(0, 1200) || 'unknown';
}

function titleParts(value) {
  return clean(value)
    .split(/[:\-–—]+/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function setNameAliases(setName) {
  const aliases = new Set();
  const raw = clean(setName);
  if (raw) aliases.add(raw);

  for (const part of titleParts(raw)) {
    if (part) aliases.add(part);
  }

  const lower = raw.toLowerCase();
  if (lower.includes('chaos rising')) aliases.add('Chaos Rising');
  if (lower.includes('ascended heroes') || lower.includes('ascended hero')) aliases.add('Ascended Heroes');
  if (lower.includes('mega evolution')) aliases.add('Mega Evolution');

  return Array.from(aliases);
}

function cardItemName(item) {
  return clean(item.name || item.cardName || item.title);
}

function cardItemSetName(item) {
  const setValue = item.set || item.setInfo || item.expansion;
  if (typeof setValue === 'string') return clean(setValue);
  if (setValue && typeof setValue === 'object') {
    return clean(
      setValue.name ||
        setValue.setName ||
        setValue.title ||
        setValue.code ||
        setValue.id,
    );
  }

  return clean(
    item.set_name ||
      item.setName ||
      item.expansionName ||
      item.productSet ||
      item.groupName,
  );
}

function cardItemNumber(item) {
  return clean(
    item.number ||
      item.cardNumber ||
      item.collectorNumber ||
      item.collector_number ||
      item.displayNumber ||
      item.localId,
  );
}

function scoreCardMatch(item, target) {
  const name = normalise(cardItemName(item));
  const setName = normalise(cardItemSetName(item));
  const number = normaliseCardNumber(cardItemNumber(item));
  let score = 0;

  if (name && name === target.name) score += 600;
  else if (name && (name.includes(target.name) || target.name.includes(name))) score += 300;
  else if (compact(name) && compact(name) === compact(target.name)) score += 280;

  if (setName && target.setAliases.some((alias) => setName === normalise(alias))) score += 420;
  else if (
    setName &&
    target.setAliases.some((alias) => {
      const normAlias = normalise(alias);
      return normAlias && (setName.includes(normAlias) || normAlias.includes(setName));
    })
  ) {
    score += 210;
  }

  if (number && target.number && number === target.number) score += 320;
  if (name === target.name && number && target.number && number === target.number) score += 180;

  return score;
}

function numericPrice(value) {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) return value;
  const parsed = Number(clean(value).replace(/[^0-9.\-]+/g, ''));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function getFirstPrice(source) {
  if (!source || typeof source !== 'object') return 0;

  const keys = [
    'price',
    'marketPrice',
    'market',
    'value',
    'mid',
    'average',
    'avg',
    'low',
    'lowPrice',
    'lastSold',
    'lastSale',
  ];

  for (const key of keys) {
    const price = numericPrice(source[key]);
    if (price > 0) return price;
  }

  return 0;
}

function flattenVariants(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value.filter((item) => item && typeof item === 'object');
  if (typeof value !== 'object') return [];

  const flattened = [];
  for (const [key, item] of Object.entries(value)) {
    if (Array.isArray(item)) {
      for (const child of item) {
        if (child && typeof child === 'object') {
          flattened.push({ printing: key, ...child });
        }
      }
      continue;
    }
    if (item && typeof item === 'object') {
      flattened.push({ printing: key, ...item });
    }
  }
  return flattened;
}

function cardVariants(card) {
  const variants = [
    ...flattenVariants(card.variants),
    ...flattenVariants(card.prices),
    ...flattenVariants(card.marketPrices),
    ...flattenVariants(card.market_prices),
    ...flattenVariants(card.conditions),
  ];

  const directPrice = getFirstPrice(card);
  if (directPrice > 0) variants.push({ price: directPrice, condition: 'Near Mint', printing: 'Normal' });

  return variants;
}

function variantScore(variant) {
  const condition = normalise(variant.condition || variant.conditionName || variant.grade);
  const printing = normalise(variant.printing || variant.finish || variant.variant || variant.type);
  let score = 0;

  if (condition === 'near mint' || condition === 'nm' || condition.includes('near mint')) score += 320;
  else if (condition.includes('lightly played') || condition === 'lp') score += 120;
  else if (!condition) score += 30;

  if (printing === 'normal' || printing === 'regular') score += 140;
  else if (printing.includes('reverse')) score += 120;
  else if (printing.includes('holo') || printing.includes('foil')) score += 100;
  else if (!printing) score += 20;

  return score;
}

function bestVariant(card) {
  const variants = cardVariants(card)
    .map((variant) => ({ variant, price: getFirstPrice(variant) }))
    .filter((entry) => entry.price > 0)
    .sort((a, b) => variantScore(b.variant) - variantScore(a.variant));

  return variants[0] || null;
}

function extractItems(json) {
  if (Array.isArray(json)) return json;
  if (!json || typeof json !== 'object') return [];
  if (Array.isArray(json.data)) return json.data;
  if (Array.isArray(json.results)) return json.results;
  if (Array.isArray(json.cards)) return json.cards;
  if (json.data && Array.isArray(json.data.cards)) return json.data.cards;
  return [];
}

function buildSearches({ name, setName, number, target }) {
  const mainSetAlias = target.setAliases[0] || setName;
  const searches = [];

  searches.push({
    game: 'pokemon',
    q: [name, mainSetAlias, number].filter(Boolean).join(' '),
    condition: 'NM',
    limit: '10',
  });

  // Only one backup request. The previous version did many requests per card,
  // which quickly used the JustTCG free-tier rate limit.
  searches.push({
    game: 'pokemon',
    name,
    number,
    condition: 'NM',
    limit: '10',
  });

  return searches;
}

async function fetchJustTcg(params, apiKey) {
  const url = new URL(JUSTTCG_BASE_URL);
  Object.entries(params).forEach(([key, value]) => {
    const safeValue = clean(value);
    if (safeValue) url.searchParams.set(key, safeValue);
  });

  const response = await fetch(url.toString(), {
    headers: {
      'x-api-key': clean(apiKey),
      accept: 'application/json',
    },
  });

  if (!response.ok) {
    let errorText = '';
    try {
      errorText = (await response.text()).substring(0, 280);
    } catch (_) {
      errorText = '';
    }

    logger.warn('JustTCG HTTP request failed.', {
      status: response.status,
      statusText: response.statusText,
      url: url.toString(),
      body: errorText,
      keyPresent: clean(apiKey).length > 0,
      keyPrefix: clean(apiKey).substring(0, 4),
    });

    if (response.status === 429) {
      throw new HttpsError(
        'resource-exhausted',
        errorText || 'JustTCG rate limit exceeded. Please wait and try again.',
      );
    }

    throw new HttpsError(
      'unavailable',
      errorText
        ? `JustTCG request failed with HTTP ${response.status}: ${errorText}`
        : `JustTCG request failed with HTTP ${response.status}`,
    );
  }

  const json = await response.json();
  return extractItems(json);
}

async function readCache(cacheRef) {
  try {
    const snapshot = await cacheRef.get();
    if (!snapshot.exists) return null;

    const data = snapshot.data() || {};
    const expiresAtMs = Number(data.expiresAtMs || 0);
    if (expiresAtMs <= Date.now()) return null;

    return data.response || null;
  } catch (error) {
    logger.warn('Could not read external price cache.', {
      error: error && error.message ? error.message : String(error),
    });
    return null;
  }
}

async function writeCache(cacheRef, response, ttlMs) {
  try {
    await cacheRef.set(
      {
        response,
        updatedAtMs: Date.now(),
        expiresAtMs: Date.now() + ttlMs,
      },
      { merge: true },
    );
  } catch (error) {
    logger.warn('Could not write external price cache.', {
      error: error && error.message ? error.message : String(error),
    });
  }
}

exports.lookupExternalPokemonCardPrice = onCall(
  {
    region: 'europe-west2',
    secrets: [JUSTTCG_API_KEY],
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Please sign in first.');
    }

    const apiKey = clean(JUSTTCG_API_KEY.value());
    if (!apiKey) {
      throw new HttpsError(
        'failed-precondition',
        'Missing JUSTTCG_API_KEY secret on Firebase Functions.',
      );
    }

    const data = request.data || {};
    const name = clean(data.name);
    const setName = clean(data.setName);
    const number = clean(data.number);
    const cardId = clean(data.cardId);

    if (!name) return { found: false, reason: 'missing_name' };

    const target = {
      name: normalise(name),
      setAliases: setNameAliases(setName),
      number: normaliseCardNumber(number),
    };

    const cacheKey = safeCacheId([
      'pokemon',
      cardId || target.name,
      normalise(setName),
      target.number,
    ].join('|'));
    const cacheRef = db.collection(CACHE_COLLECTION).doc(cacheKey);

    const cached = await readCache(cacheRef);
    if (cached) {
      return { ...cached, cached: true };
    }

    const searches = buildSearches({ name, setName, number, target });
    const seenIds = new Set();
    const allMatches = [];

    for (const params of searches) {
      let results;
      try {
        results = await fetchJustTcg(params, apiKey);
      } catch (error) {
        if (error && error.code === 'resource-exhausted') {
          const response = {
            found: false,
            reason: 'rate_limited',
            message: 'JustTCG is rate limited. Please wait a minute and try again.',
          };
          await writeCache(cacheRef, response, RATE_LIMIT_CACHE_MS);
          return response;
        }
        throw error;
      }

      for (const item of results) {
        const id = clean(item.id || item.uuid || `${cardItemName(item)}|${cardItemSetName(item)}|${cardItemNumber(item)}`);
        if (!id || seenIds.has(id)) continue;
        seenIds.add(id);
        allMatches.push(item);
      }

      // If the first request already found useful candidates, do not spend a
      // second rate-limited request.
      const hasStrongCandidate = allMatches.some((item) => scoreCardMatch(item, target) >= 520);
      if (hasStrongCandidate) break;
    }

    const sortedCards = allMatches
      .map((item) => ({ item, score: scoreCardMatch(item, target) }))
      .filter((entry) => entry.score >= 520)
      .sort((a, b) => b.score - a.score);

    for (const entry of sortedCards) {
      const best = bestVariant(entry.item);
      if (!best) continue;

      const variant = best.variant;
      const lastUpdatedRaw = Number(
        variant.lastUpdated ||
          variant.last_updated ||
          variant.updatedAt ||
          variant.updated_at ||
          0,
      );
      const lastUpdatedMs = lastUpdatedRaw > 0
        ? lastUpdatedRaw < 100000000000 ? lastUpdatedRaw * 1000 : lastUpdatedRaw
        : Date.now();

      const response = {
        found: true,
        amount: best.price,
        currencyCode: clean(variant.currency || variant.currencyCode || 'USD') || 'USD',
        source: 'JustTCG',
        providerCardId: clean(entry.item.id || entry.item.uuid),
        providerVariantId: clean(variant.id || variant.uuid),
        printing: clean(variant.printing || variant.finish || variant.variant || variant.type),
        condition: clean(variant.condition || variant.conditionName || variant.grade),
        lastUpdatedMs,
      };

      await writeCache(cacheRef, response, SUCCESS_CACHE_MS);
      return response;
    }

    const response = {
      found: false,
      reason: 'no_matching_price',
      candidateCount: allMatches.length,
    };
    await writeCache(cacheRef, response, NO_MATCH_CACHE_MS);

    logger.info('No JustTCG price match found.', {
      name,
      setName,
      number,
      candidateCount: allMatches.length,
      target,
    });

    return response;
  },
);
