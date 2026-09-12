// PocketChase catalogue-style sealed product pricing.
// Uses eBay Browse for the live price and eBay Catalog for a clean product image.
// Seller photos and seller titles are never returned to Flutter.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const EBAY_CLIENT_ID = defineSecret('EBAY_CLIENT_ID');
const EBAY_CLIENT_SECRET = defineSecret('EBAY_CLIENT_SECRET');

const REGION = 'europe-west2';
const EBAY_TOKEN_URL = 'https://api.ebay.com/identity/v1/oauth2/token';
const EBAY_BROWSE_URL =
  'https://api.ebay.com/buy/browse/v1/item_summary/search';
const EBAY_CATALOG_URL =
  'https://api.ebay.com/commerce/catalog/v1_beta/product_summary/search';
const EBAY_SCOPE = 'https://api.ebay.com/oauth/api_scope';
const CACHE_COLLECTION = 'ebay_sealed_listing_cache';
const MANUAL_CATALOG_COLLECTION = 'sealed_product_catalog';

const SUCCESS_CACHE_MS = 10 * 60 * 1000;
const EMPTY_CACHE_MS = 2 * 60 * 1000;
const MAX_QUERY_LENGTH = 72;
const RESULTS_PER_TYPE = 24;
const CATALOG_RESULTS_PER_TYPE = 12;

let applicationToken = '';
let applicationTokenExpiresAtMs = 0;

const MARKETPLACES = {
  UK: {
    ebayMarketplaceId: 'EBAY_GB',
    country: 'GB',
    label: 'eBay UK',
    searchDomain: 'www.ebay.co.uk',
  },
  US: {
    ebayMarketplaceId: 'EBAY_US',
    country: 'US',
    label: 'eBay US',
    searchDomain: 'www.ebay.com',
  },
  IE: {
    ebayMarketplaceId: 'EBAY_IE',
    country: 'IE',
    label: 'eBay Ireland',
    searchDomain: 'www.ebay.ie',
  },
  CA: {
    ebayMarketplaceId: 'EBAY_CA',
    country: 'CA',
    label: 'eBay Canada',
    searchDomain: 'www.ebay.ca',
  },
  AU: {
    ebayMarketplaceId: 'EBAY_AU',
    country: 'AU',
    label: 'eBay Australia',
    searchDomain: 'www.ebay.com.au',
  },
};

const PRODUCT_TYPES = {
  boosterBox: {
    label: 'Booster Box',
    searchPhrase: 'booster box',
  },
  eliteTrainerBox: {
    label: 'Elite Trainer Box',
    searchPhrase: 'elite trainer box',
  },
  boosterBundle: {
    label: 'Booster Bundle',
    searchPhrase: 'booster bundle',
  },
  ultraPremiumCollection: {
    label: 'Ultra-Premium Collection (UPC)',
    searchPhrase: 'ultra premium collection',
  },
};

const GENERIC_SEARCH_WORDS = new Set([
  'pokemon',
  'tcg',
  'sealed',
  'new',
  'english',
  'version',
  'the',
  'and',
  'of',
  'for',
  'with',
]);

const PRODUCT_TYPE_SEARCH_WORDS = new Set([
  'booster',
  'box',
  'bundle',
  'elite',
  'trainer',
  'etb',
  'upc',
  'ultra',
  'premium',
  'collection',
]);

const UNWANTED_COMPONENT_TITLE_PARTS = [
  'empty box',
  'box only',
  'empty upc',
  'upc box only',
  'acrylic case',
  'protective case',
  'sealed case',
  'master case',
  'display stand',
  'pack art set',
  'opened',
  'open box',
  'wrapper only',
  'contents only',
  'replacement contents',
  'replacement part',
  'replacement parts',
  'single card',
  'card only',
  'trading card',
  'promo card',
  'promo cards',
  'graded card',
  'booster pack',
  'single pack',
  'loose pack',
  'loose packs',
  'pack only',
  'code card',
  'code only',
  'sleeves',
  'sleeve',
  'deck box',
  'playmat',
  'play mat',
  'coin only',
  'dice only',
  'pin only',
  'poster',
  'binder',
  'booklet',
  'insert only',
  'lid only',
  'divider only',
  'accessory',
  'accessories',
  'job lot',
  'mixed lot',
];

const COMPONENT_WORDS = [
  'coin',
  'coins',
  'gold metal coin',
  'metal coin',
  'metal card',
  'gold card',
  'promo card',
  'promo cards',
  'card only',
  'single card',
];

const COMPLETE_PRODUCT_CUES = [
  'sealed',
  'factory sealed',
  'brand new',
  'new in box',
  'collection box',
  'upc box',
  'ultra premium collection box',
  'booster box',
  'booster bundle',
  'elite trainer box',
  'etb',
];

function clean(value) {
  return String(value || '').trim();
}

function cleanLower(value) {
  return clean(value).toLowerCase();
}

function normalise(value) {
  return cleanLower(value)
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function safeCacheId(value) {
  return clean(value)
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .substring(0, 1200) || 'unknown';
}

function cleanSearchQuery(value) {
  return clean(value)
    .replace(/[<>]/g, '')
    .replace(/\s+/g, ' ')
    .substring(0, MAX_QUERY_LENGTH);
}

function numeric(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number(clean(value).replace(/[^0-9.\-]+/g, ''));
  return Number.isFinite(parsed) ? parsed : 0;
}

function marketplaceFor(code) {
  return MARKETPLACES[clean(code).toUpperCase()] || MARKETPLACES.UK;
}

function productTypesFor(type) {
  const selected = clean(type);
  if (PRODUCT_TYPES[selected]) return [selected];
  return Object.keys(PRODUCT_TYPES);
}

function titleProductType(title) {
  const normalized = normalise(title);

  if (
    normalized.includes('elite trainer box') ||
    /(^|\s)etb($|\s)/.test(normalized)
  ) {
    return 'eliteTrainerBox';
  }

  if (normalized.includes('booster bundle')) {
    return 'boosterBundle';
  }

  if (normalized.includes('booster box')) {
    return 'boosterBox';
  }

  if (
    normalized.includes('ultra premium collection') ||
    /(^|\s)upc($|\s)/.test(normalized)
  ) {
    return 'ultraPremiumCollection';
  }

  return '';
}

function hasNormalisedPhrase(normalizedValue, phrase) {
  const normalizedPhrase = normalise(phrase);
  if (!normalizedPhrase) return false;
  return ` ${normalizedValue} `.includes(` ${normalizedPhrase} `);
}

function hasAnyPhrase(normalizedTitle, phrases) {
  return phrases.some((phrase) => hasNormalisedPhrase(normalizedTitle, phrase));
}

function productTokensFromQuery(query) {
  return normalise(query)
    .split(' ')
    .filter((word) =>
      word.length > 1 &&
      !GENERIC_SEARCH_WORDS.has(word) &&
      !PRODUCT_TYPE_SEARCH_WORDS.has(word),
    );
}

function titleMatchesRequestedProduct(normalizedTitle, requestedQuery) {
  const productTokens = productTokensFromQuery(requestedQuery);
  if (productTokens.length === 0) return true;

  return productTokens.every((token) =>
    hasNormalisedPhrase(normalizedTitle, token),
  );
}

function looksLikeAComponentOnlyListing(item, normalizedTitle, requestedType) {
  const priceAmount = numeric(item && item.price && item.price.value);
  const mentionsAComponent = hasAnyPhrase(normalizedTitle, COMPONENT_WORDS);
  if (!mentionsAComponent) return false;

  const hasCompleteProductCue = hasAnyPhrase(
    normalizedTitle,
    COMPLETE_PRODUCT_CUES,
  );

  const suspiciouslyLowPrice =
    requestedType === 'ultraPremiumCollection' &&
    priceAmount > 0 &&
    priceAmount < 40;

  return !hasCompleteProductCue || suspiciouslyLowPrice;
}

function shouldKeepListing(item, requestedType, requestedQuery) {
  const title = clean(item && item.title);
  const normalizedTitle = normalise(title);
  if (!title || !normalizedTitle) return false;

  if (titleProductType(title) !== requestedType) return false;
  if (!titleMatchesRequestedProduct(normalizedTitle, requestedQuery)) return false;
  if (hasAnyPhrase(normalizedTitle, UNWANTED_COMPONENT_TITLE_PARTS)) return false;

  return !looksLikeAComponentOnlyListing(item, normalizedTitle, requestedType);
}

function listingMatchScore(item, requestedType, requestedQuery) {
  const title = clean(item && item.title);
  const normalizedTitle = normalise(title);
  let score = 0;

  if (hasNormalisedPhrase(normalizedTitle, PRODUCT_TYPES[requestedType].searchPhrase)) {
    score += 80;
  }
  if (hasAnyPhrase(normalizedTitle, COMPLETE_PRODUCT_CUES)) score += 40;

  const productTokens = productTokensFromQuery(requestedQuery);
  score += productTokens.filter((token) =>
    hasNormalisedPhrase(normalizedTitle, token),
  ).length * 10;

  if (clean(item && item.condition).toLowerCase().includes('new')) score += 8;

  const total =
    numeric(item && item.price && item.price.value) +
    numeric(
      item &&
      item.shippingOptions &&
      item.shippingOptions[0] &&
      item.shippingOptions[0].shippingCost &&
      item.shippingOptions[0].shippingCost.value,
    );
  if (total >= 40) score += 4;

  return score;
}

function productSearchQuery(query, type) {
  const product = PRODUCT_TYPES[type];
  const parts = ['pokemon'];
  if (query) parts.push(query);
  parts.push(product.searchPhrase, 'sealed');
  return parts.join(' ').replace(/\s+/g, ' ').trim().substring(0, 100);
}

function displayTitleFromQuery(query, type) {
  const typedTitle = clean(query).replace(/\bupc\b/ig, 'Ultra-Premium Collection');
  const normalizedTitle = normalise(typedTitle);
  const typePhrase = PRODUCT_TYPES[type].searchPhrase;

  const titleWithType = hasNormalisedPhrase(normalizedTitle, typePhrase)
    ? typedTitle
    : `${typedTitle} ${PRODUCT_TYPES[type].label}`;

  return `Pokémon TCG: ${titleWithType}`.replace(/\s+/g, ' ').trim();
}

function buildEbaySearchUrl(marketplace, query, type) {
  const url = new URL(`https://${marketplace.searchDomain}/sch/i.html`);
  url.searchParams.set('_nkw', productSearchQuery(query, type));
  url.searchParams.set('LH_BIN', '1');
  return url.toString();
}

async function readCache(cacheRef) {
  try {
    const snapshot = await cacheRef.get();
    if (!snapshot.exists) return null;

    const data = snapshot.data() || {};
    if (Number(data.expiresAtMs || 0) <= Date.now()) return null;
    return data.response || null;
  } catch (error) {
    logger.warn('Could not read sealed listing cache.', {
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
    logger.warn('Could not write sealed listing cache.', {
      error: error && error.message ? error.message : String(error),
    });
  }
}

async function getApplicationAccessToken(clientId, clientSecret) {
  const now = Date.now();
  if (applicationToken && applicationTokenExpiresAtMs > now + 60000) {
    return applicationToken;
  }

  const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const response = await fetch(EBAY_TOKEN_URL, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      scope: EBAY_SCOPE,
    }).toString(),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    logger.error('Could not create eBay application access token.', {
      status: response.status,
      body: body.substring(0, 280),
    });
    throw new HttpsError(
      'unavailable',
      'eBay could not authorise sealed-price lookup. Check the eBay app credentials.',
    );
  }

  const data = await response.json();
  const token = clean(data.access_token);
  const expiresInSeconds = numeric(data.expires_in);

  if (!token) {
    throw new HttpsError(
      'unavailable',
      'eBay did not return an access token for sealed-price lookup.',
    );
  }

  applicationToken = token;
  applicationTokenExpiresAtMs =
    Date.now() + Math.max(60, expiresInSeconds || 7200) * 1000;

  return applicationToken;
}

async function searchEbayListings({ accessToken, marketplace, query }) {
  const url = new URL(EBAY_BROWSE_URL);
  url.searchParams.set('q', query);
  url.searchParams.set('limit', String(RESULTS_PER_TYPE));
  url.searchParams.set('sort', 'price');
  url.searchParams.set('filter', `deliveryCountry:${marketplace.country}`);

  const response = await fetch(url.toString(), {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      accept: 'application/json',
      'X-EBAY-C-MARKETPLACE-ID': marketplace.ebayMarketplaceId,
      'X-EBAY-C-ENDUSERCTX': `contextualLocation=country%3D${marketplace.country}`,
    },
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    logger.warn('eBay sealed listing search failed.', {
      status: response.status,
      marketplace: marketplace.ebayMarketplaceId,
      query,
      body: body.substring(0, 280),
    });

    if (response.status === 429) {
      throw new HttpsError(
        'resource-exhausted',
        'eBay is rate limiting sealed-price searches. Please try again shortly.',
      );
    }

    throw new HttpsError(
      'unavailable',
      'Could not get current eBay sealed listings right now.',
    );
  }

  const payload = await response.json();
  return Array.isArray(payload.itemSummaries) ? payload.itemSummaries : [];
}

async function searchEbayCatalogue({ accessToken, marketplace, query }) {
  const url = new URL(EBAY_CATALOG_URL);
  url.searchParams.set('q', query);
  url.searchParams.set('limit', String(CATALOG_RESULTS_PER_TYPE));

  try {
    const response = await fetch(url.toString(), {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        accept: 'application/json',
        'X-EBAY-C-MARKETPLACE-ID': marketplace.ebayMarketplaceId,
      },
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      logger.info('eBay catalogue image lookup unavailable; continuing without a photo.', {
        status: response.status,
        marketplace: marketplace.ebayMarketplaceId,
        query,
        body: body.substring(0, 160),
      });
      return [];
    }

    const payload = await response.json();
    return Array.isArray(payload.productSummaries)
      ? payload.productSummaries
      : [];
  } catch (error) {
    logger.info('eBay catalogue image lookup failed; continuing without a photo.', {
      error: error && error.message ? error.message : String(error),
      query,
    });
    return [];
  }
}

async function loadManualCatalogueEntry({ query, type }) {
  const documentId = safeCacheId(`${type}__${normalise(query)}`);
  try {
    const snapshot = await db
      .collection(MANUAL_CATALOG_COLLECTION)
      .doc(documentId)
      .get();

    if (!snapshot.exists) return null;

    const data = snapshot.data() || {};
    const title = clean(data.title);
    const imageUrl = clean(data.imageUrl);
    if (!title && !imageUrl) return null;

    return {
      title,
      imageUrl,
      productId: documentId,
      source: 'manual',
    };
  } catch (error) {
    logger.info('Could not read manual sealed product catalogue entry.', {
      error: error && error.message ? error.message : String(error),
      documentId,
    });
    return null;
  }
}

function catalogueMatchScore(product, requestedType, requestedQuery) {
  const title = clean(product && product.title);
  const normalizedTitle = normalise(title);
  if (!title || !normalizedTitle) return -1;

  const detectedType = titleProductType(title);
  if (detectedType && detectedType !== requestedType) return -1;
  if (!titleMatchesRequestedProduct(normalizedTitle, requestedQuery)) return -1;
  if (hasAnyPhrase(normalizedTitle, UNWANTED_COMPONENT_TITLE_PARTS)) return -1;

  let score = 0;
  if (hasNormalisedPhrase(normalizedTitle, PRODUCT_TYPES[requestedType].searchPhrase)) {
    score += 80;
  }
  if (detectedType === requestedType) score += 20;
  if (clean(product && product.image && product.image.imageUrl)) score += 18;

  const productTokens = productTokensFromQuery(requestedQuery);
  score += productTokens.filter((token) =>
    hasNormalisedPhrase(normalizedTitle, token),
  ).length * 10;

  return score;
}

function selectCatalogueProduct(products, requestedType, requestedQuery) {
  const candidates = products
    .map((product) => ({
      product,
      score: catalogueMatchScore(product, requestedType, requestedQuery),
    }))
    .filter((candidate) => candidate.score >= 0)
    .sort((a, b) => b.score - a.score);

  const best = candidates[0] && candidates[0].product;
  if (!best) return null;

  return {
    title: clean(best.title),
    imageUrl: clean(best && best.image && best.image.imageUrl),
    productId: clean(best.productId || best.epid || best.productHref),
    source: 'ebay-catalogue',
  };
}

function listingPriceAndCurrency(item) {
  const itemPrice = numeric(item && item.price && item.price.value);
  const shippingOption = Array.isArray(item && item.shippingOptions)
    ? item.shippingOptions[0]
    : null;
  const shippingPrice = numeric(
    shippingOption && shippingOption.shippingCost && shippingOption.shippingCost.value,
  );

  return {
    total: itemPrice + shippingPrice,
    currencyCode: clean(
      (item && item.price && item.price.currency) ||
      (shippingOption && shippingOption.shippingCost && shippingOption.shippingCost.currency),
    ).toUpperCase(),
  };
}

function toCatalogueStyleResult({
  item,
  type,
  query,
  marketplace,
  manualCatalogue,
  ebayCatalogue,
}) {
  const price = listingPriceAndCurrency(item);
  const catalogue = manualCatalogue || ebayCatalogue;

  return {
    listingId: clean(
      (catalogue && catalogue.productId) ||
      (item && (item.itemId || item.legacyItemId)),
    ),
    title: clean(catalogue && catalogue.title) || displayTitleFromQuery(query, type),
    // Deliberately catalogue-only. Never use an individual seller image here.
    imageUrl: clean(catalogue && catalogue.imageUrl),
    listingUrl: buildEbaySearchUrl(marketplace, query, type),
    // This is one clear all-in amount, not separate seller price/shipping rows.
    priceAmount: price.total,
    shippingAmount: 0,
    currencyCode: price.currencyCode,
    productType: type,
    productTypeLabel: PRODUCT_TYPES[type].label,
    condition: '',
    sellerName: '',
    location: '',
    catalogueImageFound: Boolean(clean(catalogue && catalogue.imageUrl)),
    catalogueSource: clean(catalogue && catalogue.source),
  };
}

exports.lookupEbaySealedProducts = onCall(
  {
    region: REGION,
    secrets: [EBAY_CLIENT_ID, EBAY_CLIENT_SECRET],
    timeoutSeconds: 45,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Please sign in first.');
    }

    const clientId = clean(EBAY_CLIENT_ID.value());
    const clientSecret = clean(EBAY_CLIENT_SECRET.value());
    if (!clientId || !clientSecret) {
      throw new HttpsError(
        'failed-precondition',
        'Missing eBay credentials. Add EBAY_CLIENT_ID and EBAY_CLIENT_SECRET in Firebase Functions secrets.',
      );
    }

    const data = request.data || {};
    const query = cleanSearchQuery(data.query);
    const marketplaceCode = clean(data.marketplaceCode).toUpperCase() || 'UK';
    const marketplace = marketplaceFor(marketplaceCode);
    const selectedTypes = productTypesFor(data.productType);

    const cacheKey = safeCacheId(
      [
        'sealed-v5-catalogue-card',
        marketplaceCode,
        query || 'browse',
        selectedTypes.join(','),
      ].join('|'),
    );
    const cacheRef = db.collection(CACHE_COLLECTION).doc(cacheKey);
    const cached = await readCache(cacheRef);
    if (cached) {
      return { ...cached, cached: true };
    }

    const accessToken = await getApplicationAccessToken(clientId, clientSecret);

    const settled = await Promise.allSettled(
      selectedTypes.map(async (type) => {
        const eBayQuery = productSearchQuery(query, type);
        const [listingResults, catalogueResults, manualCatalogue] = await Promise.all([
          searchEbayListings({
            accessToken,
            marketplace,
            query: eBayQuery,
          }),
          searchEbayCatalogue({
            accessToken,
            marketplace,
            query: eBayQuery,
          }),
          loadManualCatalogueEntry({ query, type }),
        ]);

        const bestListing = listingResults
          .filter((item) => shouldKeepListing(item, type, query))
          .map((item) => ({
            item,
            score: listingMatchScore(item, type, query),
            price: listingPriceAndCurrency(item).total,
          }))
          .sort((a, b) => {
            const scoreDifference = b.score - a.score;
            if (scoreDifference !== 0) return scoreDifference;
            return a.price - b.price;
          })[0];

        if (!bestListing || bestListing.price <= 0) return null;

        const ebayCatalogue = selectCatalogueProduct(
          catalogueResults,
          type,
          query,
        );

        return toCatalogueStyleResult({
          item: bestListing.item,
          type,
          query,
          marketplace,
          manualCatalogue,
          ebayCatalogue,
        });
      }),
    );

    const items = [];
    let lastError = null;

    for (const result of settled) {
      if (result.status === 'rejected') {
        lastError = result.reason;
        continue;
      }
      if (result.value && result.value.priceAmount > 0) {
        items.push(result.value);
      }
    }

    items.sort((a, b) => a.priceAmount - b.priceAmount);
    const bestItem = items[0] || null;
    const outputItems = bestItem ? [bestItem] : [];

    if (outputItems.length === 0 && lastError) {
      if (lastError instanceof HttpsError) throw lastError;
      throw new HttpsError(
        'unavailable',
        'Could not get current eBay sealed listings right now.',
      );
    }

    const response = {
      found: outputItems.length > 0,
      marketplaceCode,
      marketplaceLabel: marketplace.label,
      query,
      itemCount: outputItems.length,
      items: outputItems,
      lastUpdatedMs: Date.now(),
    };

    await writeCache(
      cacheRef,
      response,
      outputItems.isEmpty ? EMPTY_CACHE_MS : SUCCESS_CACHE_MS,
    );

    logger.info('Catalogue-style sealed product result returned.', {
      marketplaceCode,
      query,
      productTypes: selectedTypes,
      itemCount: outputItems.length,
      usedCatalogueImage: Boolean(bestItem && bestItem.catalogueImageFound),
      catalogueSource: bestItem && bestItem.catalogueSource,
    });

    return response;
  },
);
