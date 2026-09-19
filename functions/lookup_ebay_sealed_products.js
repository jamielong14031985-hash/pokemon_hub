// PocketChase sealed products currently for sale.
// Firebase callable: lookupEbaySealedProducts
// Returns up to 10 current sealed-product listings from the eBay Browse API.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const EBAY_CLIENT_ID = defineSecret('EBAY_CLIENT_ID');
const EBAY_CLIENT_SECRET = defineSecret('EBAY_CLIENT_SECRET');

const REGION = 'europe-west2';
const EBAY_TOKEN_URL = 'https://api.ebay.com/identity/v1/oauth2/token';
const EBAY_BROWSE_URL = 'https://api.ebay.com/buy/browse/v1/item_summary/search';
const EBAY_SCOPE = 'https://api.ebay.com/oauth/api_scope';
const CACHE_COLLECTION = 'ebay_sealed_listing_cache';

const SUCCESS_CACHE_MS = 30 * 60 * 1000;
const EMPTY_CACHE_MS = 5 * 60 * 1000;
const MAX_QUERY_LENGTH = 72;
// Keep each eBay request at the known-working size. We run a small number of
// alternative searches below, then merge and filter them before returning 10.
const RESULTS_PER_TYPE = 10;
const RETURN_LIMIT = 10;
const CACHE_VERSION = 'sealed_active_v1';

let applicationToken = '';
let applicationTokenExpiresAtMs = 0;

const MARKETPLACES = {
  UK: { ebayMarketplaceId: 'EBAY_GB', country: 'GB', label: 'eBay UK' },
  US: { ebayMarketplaceId: 'EBAY_US', country: 'US', label: 'eBay US' },
  IE: { ebayMarketplaceId: 'EBAY_IE', country: 'IE', label: 'eBay Ireland' },
  CA: { ebayMarketplaceId: 'EBAY_CA', country: 'CA', label: 'eBay Canada' },
  AU: { ebayMarketplaceId: 'EBAY_AU', country: 'AU', label: 'eBay Australia' },
};

const PRODUCT_TYPES = {
  boosterBox: { label: 'Booster Box', searchPhrase: 'booster box' },
  eliteTrainerBox: { label: 'Elite Trainer Box', searchPhrase: 'elite trainer box' },
  boosterBundle: { label: 'Booster Bundle', searchPhrase: 'booster bundle' },
  ultraPremiumCollection: { label: 'Ultra-Premium Collection', searchPhrase: 'ultra premium collection' },
};

function clean(value) { return String(value || '').trim(); }
function cleanLower(value) { return clean(value).toLowerCase(); }
function normalise(value) {
  return cleanLower(value).replace(/&/g, 'and').replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
}
function safeCacheId(value) {
  return clean(value).toLowerCase().replace(/[^a-z0-9_-]+/g, '_').replace(/_+/g, '_').replace(/^_|_$/g, '').substring(0, 1200) || 'unknown';
}
function cleanSearchQuery(value) {
  return clean(value).replace(/[<>]/g, '').replace(/\s+/g, ' ').substring(0, MAX_QUERY_LENGTH);
}
function numeric(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number(clean(value).replace(/[^0-9.\-]+/g, ''));
  return Number.isFinite(parsed) ? parsed : 0;
}
function marketplaceFor(code) { return MARKETPLACES[clean(code).toUpperCase()] || MARKETPLACES.UK; }
function productTypesFor(type) {
  const selected = clean(type);
  if (PRODUCT_TYPES[selected]) return [selected];
  return Object.keys(PRODUCT_TYPES);
}
function titleProductType(title) {
  const normalized = normalise(title);
  if (normalized.includes('ultra premium collection') || normalized.includes('ultra premium') || /(^|\s)upc($|\s)/.test(normalized)) return 'ultraPremiumCollection';
  if (normalized.includes('elite trainer box') || /(^|\s)etb($|\s)/.test(normalized)) return 'eliteTrainerBox';
  if (normalized.includes('booster bundle')) return 'boosterBundle';
  if (normalized.includes('booster box')) return 'boosterBox';
  return '';
}
function shouldKeepListing(item, requestedType) {
  const title = clean(item && item.title);
  const normalizedTitle = normalise(title);
  if (!title || !normalizedTitle) return false;
  const detectedType = titleProductType(title);
  if (!detectedType || detectedType !== requestedType) return false;
  const unwanted = ['empty box', 'box only', 'acrylic case', 'protective case', 'display stand', 'pack art set', 'opened', 'wrapper only', 'digital'];
  return !unwanted.some((part) => normalizedTitle.includes(part));
}
function productSearchQueries(query, type) {
  const alternatives = {
    boosterBox: ['booster box', 'booster display'],
    eliteTrainerBox: ['elite trainer box', 'etb'],
    boosterBundle: ['booster bundle'],
    ultraPremiumCollection: ['ultra premium collection', 'upc'],
  };
  return [...new Set((alternatives[type] || [PRODUCT_TYPES[type].searchPhrase]).map((phrase) => {
    const parts = ['pokemon'];
    if (query) parts.push(query);
    parts.push(phrase);
    return parts.join(' ').replace(/\s+/g, ' ').trim().substring(0, 100);
  }))];
}
async function readCache(cacheRef) {
  try {
    const snapshot = await cacheRef.get();
    if (!snapshot.exists) return null;
    const data = snapshot.data() || {};
    if (Number(data.expiresAtMs || 0) <= Date.now()) return null;
    return data.response || null;
  } catch (error) {
    logger.warn('Could not read sealed listing cache.', { error: error && error.message ? error.message : String(error) });
    return null;
  }
}
async function writeCache(cacheRef, response, ttlMs) {
  try {
    await cacheRef.set({ response, updatedAtMs: Date.now(), expiresAtMs: Date.now() + ttlMs }, { merge: true });
  } catch (error) {
    logger.warn('Could not write sealed listing cache.', { error: error && error.message ? error.message : String(error) });
  }
}
async function getApplicationAccessToken(clientId, clientSecret) {
  const now = Date.now();
  if (applicationToken && applicationTokenExpiresAtMs > now + 60000) return applicationToken;
  const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const response = await fetch(EBAY_TOKEN_URL, {
    method: 'POST',
    headers: { Authorization: `Basic ${credentials}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'client_credentials', scope: EBAY_SCOPE }).toString(),
  });
  if (!response.ok) {
    const body = await response.text().catch(() => '');
    logger.error('Could not create eBay Browse API access token.', { status: response.status, body: body.substring(0, 400) });
    throw new HttpsError('failed-precondition', 'eBay listing search could not be connected. Check the eBay app credentials in Firebase Functions.');
  }
  const data = await response.json();
  const token = clean(data.access_token);
  const expiresInSeconds = numeric(data.expires_in);
  if (!token) throw new HttpsError('unavailable', 'eBay did not return an access token for sealed-product lookup.');
  applicationToken = token;
  applicationTokenExpiresAtMs = Date.now() + Math.max(60, expiresInSeconds || 7200) * 1000;
  return applicationToken;
}
function listingDateValue(item) {
  return clean((item && item.itemCreationDate) || (item && item.itemStartDate) || '');
}
function listingDateMs(item) {
  const parsed = Date.parse(listingDateValue(item));
  return Number.isFinite(parsed) ? parsed : 0;
}
function itemPrice(item) {
  return (item && (item.price || item.soldPrice || item.lastSoldPrice || item.currentBidPrice)) || null;
}
function itemShipping(item) {
  const option = Array.isArray(item && item.shippingOptions) ? item.shippingOptions[0] : null;
  return (item && (item.shippingCost || item.deliveryCost)) || (option && option.shippingCost) || null;
}
function responseItems(payload) {
  if (!payload || typeof payload !== 'object') return [];
  for (const candidate of [payload.itemSales, payload.itemSummaries, payload.items, payload.sales, payload.results]) {
    if (Array.isArray(candidate)) return candidate;
  }
  return [];
}
async function searchEbayListings({ accessToken, marketplace, query }) {
  const url = new URL(EBAY_BROWSE_URL);
  url.searchParams.set('q', query);
  url.searchParams.set('limit', String(RESULTS_PER_TYPE));
  url.searchParams.set('sort', 'newlyListed');
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
    logger.warn('eBay sealed listing search failed.', { status: response.status, marketplace: marketplace.ebayMarketplaceId, query, body: body.substring(0, 400) });
    if (response.status === 401 || response.status === 403) throw new HttpsError('permission-denied', 'eBay rejected the listing search credentials. Check the production eBay client ID and secret.');
    if (response.status === 429) throw new HttpsError('resource-exhausted', 'eBay is rate limiting listing searches. Please try again shortly.');
    throw new HttpsError('unavailable', 'Could not get current eBay listings right now.');
  }
  const payload = await response.json();
  return responseItems(payload);
}
function toListing(item, type) {
  const price = itemPrice(item);
  const shipping = itemShipping(item);
  const priceAmount = numeric(price && price.value);
  const shippingAmount = numeric(shipping && shipping.value);
  const currencyCode = clean((price && price.currency) || (shipping && shipping.currency) || (item && item.priceCurrency) || '').toUpperCase();
  return {
    listingId: clean(item && (item.itemId || item.legacyItemId || item.itemGroupId || item.salesRecordId || item.transactionId)),
    title: clean(item && item.title),
    imageUrl: clean(item && ((item.image && item.image.imageUrl) || (Array.isArray(item.additionalImages) && item.additionalImages[0] && item.additionalImages[0].imageUrl) || item.imageUrl)),
    listingUrl: clean(item && (item.itemWebUrl || item.itemAffiliateWebUrl || item.webUrl)),
    priceAmount,
    shippingAmount,
    currencyCode,
    listingDate: listingDateValue(item),
    listingDateMs: listingDateMs(item),
    productType: type,
    productTypeLabel: PRODUCT_TYPES[type].label,
    condition: clean(item && item.condition),
    sellerName: clean(item && item.seller && (item.seller.username || item.seller.sellerAccountType)),
    location: clean(item && item.itemLocation && (item.itemLocation.country || item.itemLocation.city)),
  };
}

exports.lookupEbaySealedProducts = onCall(
  { region: REGION, secrets: [EBAY_CLIENT_ID, EBAY_CLIENT_SECRET], timeoutSeconds: 45, memory: '256MiB' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in first.');
    const clientId = clean(EBAY_CLIENT_ID.value());
    const clientSecret = clean(EBAY_CLIENT_SECRET.value());
    if (!clientId || !clientSecret) throw new HttpsError('failed-precondition', 'Missing eBay credentials. Add EBAY_CLIENT_ID and EBAY_CLIENT_SECRET in Firebase Functions secrets.');
    const data = request.data || {};
    const query = cleanSearchQuery(data.query);
    const marketplaceCode = clean(data.marketplaceCode).toUpperCase() || 'UK';
    const marketplace = marketplaceFor(marketplaceCode);
    const selectedTypes = productTypesFor(data.productType);
    const cacheKey = safeCacheId([CACHE_VERSION, marketplaceCode, query || 'browse', selectedTypes.join(',')].join('|'));
    const cacheRef = db.collection(CACHE_COLLECTION).doc(cacheKey);
    const cached = await readCache(cacheRef);
    if (cached) return { ...cached, cached: true };
    const accessToken = await getApplicationAccessToken(clientId, clientSecret);
    const settled = await Promise.allSettled(selectedTypes.map(async (type) => {
      const searches = await Promise.allSettled(productSearchQueries(query, type).map((searchQuery) =>
        searchEbayListings({ accessToken, marketplace, query: searchQuery })));
      const results = [];
      let searchError = null;
      for (const search of searches) {
        if (search.status === 'rejected') {
          searchError = search.reason;
        } else {
          results.push(...search.value);
        }
      }
      if (results.length === 0 && searchError) throw searchError;
      return results.filter((item) => shouldKeepListing(item, type)).map((item) => toListing(item, type));
    }));
    const listingsById = new Map();
    let lastError = null;
    for (const result of settled) {
      if (result.status === 'rejected') { lastError = result.reason; continue; }
      for (const listing of result.value) {
        if (!listing.title || listing.priceAmount <= 0) continue;
        const key = listing.listingId || `${listing.title}|${listing.priceAmount}|${listing.listingDate}`;
        if (!listingsById.has(key)) listingsById.set(key, listing);
      }
    }
    const items = Array.from(listingsById.values()).sort((a, b) => {
      if (b.listingDateMs !== a.listingDateMs) return b.listingDateMs - a.listingDateMs;
      return b.priceAmount - a.priceAmount;
    }).slice(0, RETURN_LIMIT);
    if (items.length === 0 && lastError) {
      if (lastError instanceof HttpsError) throw lastError;
      throw new HttpsError('unavailable', 'Could not get current eBay listings right now.');
    }
    const response = { found: items.length > 0, marketplaceCode, marketplaceLabel: marketplace.label, query, itemCount: items.length, resultType: 'active', items, lastUpdatedMs: Date.now() };
    await writeCache(cacheRef, response, items.isEmpty ? EMPTY_CACHE_MS : SUCCESS_CACHE_MS);
    logger.info('eBay sealed active listings returned.', { marketplaceCode, query, productTypes: selectedTypes, itemCount: items.length });
    return response;
  }
);
