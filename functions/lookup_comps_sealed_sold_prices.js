'use strict';



// PocketChase: verified UK eBay SOLD prices, returned by CompsAPI.

// This is deliberately separate from lookupEbaySealedProducts (ACTIVE listings).

// Never send the CompsAPI key to Flutter.



const crypto = require('node:crypto');

const { onCall, HttpsError } = require('firebase-functions/v2/https');

const { defineSecret } = require('firebase-functions/params');

const { logger } = require('firebase-functions');

const admin = require('firebase-admin');



if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

const COMPSAPI_KEY = defineSecret('COMPSAPI_KEY');



const REGION = 'europe-west2';

const API_URL = 'https://api.compsapi.com/v1/sold';

const CACHE_COLLECTION = 'sealed_comps_uk_cache';

const CACHE_VERSION = 'uk_native_gbp_v1';

const SUCCESS_TTL_MS = 12 * 60 * 60 * 1000;

const EMPTY_TTL_MS = 30 * 60 * 1000;

const LAST_SALES_LIMIT = 20;

const REQUEST_RESULTS = 120;

const SEARCH_DAYS = 180;



const clean = (value) => String(value ?? '').trim();

const normalise = (value) => clean(value).toLowerCase()

  .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')

  .replace(/&/g, ' and ')

  .replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();



function finiteMoney(value) {

  const input = typeof value === 'number' ? value : Number(clean(value).replace(/[£,$\s]/g, ''));

  return Number.isFinite(input) && input > 0 && input < 1000000 ? input : null;

}

function roundMoney(value) { return Math.round((value + Number.EPSILON) * 100) / 100; }

function isPokemonCenter(text) {

  return /\bpokemon center\b|\bpokemon centre\b|\bpc etb\b|\bpc exclusive\b/.test(normalise(text));

}

function detectType(text) {

  const title = normalise(text);

  if (/\belite trainer box\b|\betb\b/.test(title)) return 'etb';

  if (/\bbooster bundle\b/.test(title)) return 'booster_bundle';

  if (/\bsuper premium collection\b/.test(title)) return 'super_premium_collection';
  if (/\bultra premium collection\b|\bupc\b/.test(title)) return 'upc';

  if (/\bbooster box\b|\bbooster display\b/.test(title)) return 'booster_box';

  if (/\bbooster pack\b/.test(title)) return 'booster_pack';

  if (/\bposter collection\b/.test(title)) return 'poster_collection';

  if (/\bfirst partner\b/.test(title) && /\billustration collection\b/.test(title)) {
    return 'first_partner_illustration_collection';
  }
  if (/\billustration collection\b/.test(title)) return 'illustration_collection';

  if (/\bcollection box\b|\bex box\b/.test(title)) return 'collection_box';

  if (/\bmini tin\b/.test(title)) return 'mini_tin';

  if (/\btin\b/.test(title)) return 'tin';

  return '';

}

function hasType(title, type) {

  const candidate = normalise(title);

  switch (type) {

    case 'etb': return /\belite trainer box\b|\betb\b/.test(candidate);

    case 'booster_bundle': return /\bbooster bundle\b/.test(candidate);

    case 'super_premium_collection': return /\bsuper premium collection\b/.test(candidate) && !/\bultra premium collection\b/.test(candidate);
    case 'upc': return /\bultra premium collection\b|\bupc\b/.test(candidate);

    case 'booster_box': return /\bbooster box\b|\bbooster display\b/.test(candidate);

    case 'booster_pack': return /\bbooster pack\b/.test(candidate) && !/\bbooster box\b|\bbooster bundle\b/.test(candidate);

    case 'poster_collection': return /\bposter collection\b/.test(candidate);

    case 'first_partner_illustration_collection': return /\bfirst partner\b/.test(candidate) && /\billustration collection\b/.test(candidate);
    case 'illustration_collection': return /\billustration collection\b/.test(candidate);

    case 'collection_box': return /\bcollection box\b|\bex box\b/.test(candidate);

    case 'mini_tin': return /\bmini tin\b/.test(candidate);

    case 'tin': return /\btin\b/.test(candidate) && !/\bmini tin\b/.test(candidate);

    default: return true;

  }

}



const IRRELEVANT = [

  /\bempty\b/, /\bopened\b/, /\bunsealed\b/, /\bdamaged\b/,

  /\bproxy\b/, /\breplica\b/, /\bfake\b/, /\brepack\b/,

  /\bacrylic\b/, /\bprotector\b/, /\bdisplay case\b/, /\bbox only\b/,

  /\bcase only\b/, /\bwrapper only\b/, /\bcode card\b/,

  /\bplaymat\b/, /\bdigital\b/, /\bpresale\b/, /\bpreorder\b/,

  /\bcase of\b/, /\blot of\b/, /\bbulk lot\b/, /\bcollection of\b/,

  /\b(?:x|qty)\s*[2-9]\d*\b/, /\b[2-9]\d*\s*(?:x|boxes|bundles|etbs|packs)\b/,

  /\bgraded\b/, /\bpsa\s*\d+\b/,

];



const NON_IDENTIFYING_TOKENS = new Set([

  'pokemon', 'tcg', 'trading', 'card', 'game', 'sealed', 'new', 'brand', 'factory',

  'elite', 'trainer', 'etb', 'box', 'booster', 'bundle', 'pack', 'display', 'ultra',

  'premium', 'collection', 'center', 'centre', 'exclusive', 'official',

  'english', 'edition', 'standard', 'the', 'and', 'of', 'scarlet', 'violet', 'sv',

]);

function importantTokens(text) {

  return normalise(text).split(' ').filter((s) => s && !NON_IDENTIFYING_TOKENS.has(s));

}



function saleMatchesProduct(saleTitle, product) {

  const title = normalise(saleTitle);

  if (!title || IRRELEVANT.some((pattern) => pattern.test(title))) return false;

  if (!/\bpokemon\b|\bpok[eé]mon\b/.test(title)) return false;

  if (product.type && !hasType(title, product.type)) return false;

  if (product.type === 'etb' && isPokemonCenter(title) !== product.pokemonCenter) return false;

  // A UK sale for a different set/product cannot be used for this valuation.

  const required = importantTokens(product.name);

  if (required.length === 0) return false;

  const saleWords = new Set(title.split(' '));

  return required.every((token) => saleWords.has(token));

}



function productFromRequest(data) {

  const name = clean(data.productName || data.title);

  const productType = clean(data.productTypeLabel || data.productType);

  const edition = clean(data.edition);

  if (name.length < 8 || name.length > 160 || !/[a-z]/i.test(name)) {

    throw new HttpsError('invalid-argument', 'A specific sealed product name is required.');

  }

  const type = detectType(`${name} ${productType}`);

  if (!type) {

    throw new HttpsError('invalid-argument', 'Please select a recognised sealed product type before pricing.');

  }

  return {

    name, type,

    pokemonCenter: isPokemonCenter(`${name} ${edition} ${productType}`),

  };

}

function searchQuery(product) {

  // CompsAPI q requires every word: avoid adding "sealed" (often not in sold titles).

  const base = clean(product.name)

    .replace(/\(\s*(?:exclusive|standard)\s*\)/ig, '')

    .replace(/\bstandard\s+(?=elite trainer box|etb)/ig, '')

    .trim();

  const withBrand = /\bpok[eé]mon\b/i.test(base) ? base : `Pokemon ${base}`;

  if (product.type === 'etb' && product.pokemonCenter && !isPokemonCenter(withBrand)) {

    return `${withBrand} Pokemon Center`;

  }

  return withBrand;

}

function cacheKey(product) {

  const identity = `${CACHE_VERSION}|${normalise(product.name)}|${product.type}|${product.pokemonCenter}`;

  return crypto.createHash('sha256').update(identity).digest('hex');

}

async function cachedLookup(ref) {

  try {

    const snapshot = await ref.get();

    if (snapshot.exists) {

      const item = snapshot.data() || {};

      if (item.expiresAtMs > Date.now() && item.response) return item.response;

    }

  } catch (err) {

    logger.warn('Could not read CompsAPI price cache', { message: err.message });

  }

  return null;

}

async function writeCache(ref, response) {

  try {

    await ref.set({

      response,

      refreshedAtMs: Date.now(),

      expiresAtMs: Date.now() + (response.saleCount > 0 ? SUCCESS_TTL_MS : EMPTY_TTL_MS),

    });

  } catch (err) {

    logger.warn('Could not save CompsAPI price cache', { message: err.message });

  }

}

function parseSales(payload, product) {

  const rows = Array.isArray(payload.items) ? payload.items : [];

  const unique = new Map();

  for (const row of rows) {

    const currency = clean(row.native_currency).toUpperCase();

    // CompsAPI's regular 'price' and shipping_cost fields are USD even with site=UK.

    if (currency !== 'GBP') continue;

    const amount = finiteMoney(row.native_price);

    if (amount === null || !saleMatchesProduct(row.title, product)) continue;

    const date = clean(row.last_sold);

    const ms = Date.parse(date);

    if (!Number.isFinite(ms)) continue;

    const id = clean(row.item_id);

    const key = id || `${normalise(row.title)}|${date}|${amount}`;

    if (unique.has(key)) continue;

    unique.set(key, {

      itemId: id,

      title: clean(row.title),

      soldPrice: roundMoney(amount),

      currencyCode: 'GBP',

      soldDate: date,

      soldDateMs: ms,

      listingUrl: clean(row.url),

      unitsSold: Math.max(1, Math.floor(Number(row.units_sold) || 1)),

    });

  }

  return [...unique.values()]

    .sort((a, b) => b.soldDateMs - a.soldDateMs)

    .slice(0, LAST_SALES_LIMIT);

}

function summarise(items, product, query) {

  const prices = items.map((r) => r.soldPrice);

  const average = prices.length ? roundMoney(prices.reduce((a, b) => a + b, 0) / prices.length) : null;

  const last = items[0] || null;

  return {

    found: items.length > 0,

    productName: product.name,

    productType: product.type,

    pokemonCenterExclusive: product.pokemonCenter,

    source: 'CompsAPI eBay UK sold listings',

    searchQuery: query,

    currencyCode: 'GBP',

    priceIncludesShipping: false,

    lastSoldPrice: last ? last.soldPrice : null,

    lastSoldDate: last ? last.soldDate : null,

    averageSoldPrice: average,

    minSoldPrice: prices.length ? Math.min(...prices) : null,

    maxSoldPrice: prices.length ? Math.max(...prices) : null,

    saleCount: items.length,

    targetSaleCount: LAST_SALES_LIMIT,

    confidence: items.length >= 15 ? 'high' : items.length >= 5 ? 'medium' : 'low',

    lowConfidence: items.length < 5,

    // DO NOT use USD 'price' as a fallback. Unconfirmed native data is excluded.

    soldListings: items,

    lastUpdatedMs: Date.now(),

  };

}

async function getComps(key, query) {

  const url = new URL(API_URL);

  for (const [name, value] of Object.entries({

    q: query, site: 'UK', native_price: '1', days: SEARCH_DAYS,

    size: REQUEST_RESULTS, page: 1, condition: 'new', best_offer: '1',

  })) url.searchParams.set(name, String(value));

  const controller = new AbortController();

  const timeout = setTimeout(() => controller.abort(), 45000);

  let response;

  try {

    response = await fetch(url.toString(), {

      headers: { 'X-API-Key': key, 'User-Agent': 'PocketChase/1.0 (+sealed collection valuation)', Accept: 'application/json' },

      signal: controller.signal,

    });

  } catch (err) {

    throw new HttpsError('unavailable', 'The sold-price service did not respond. Please try again later.');

  } finally {

    clearTimeout(timeout);

  }

  if (!response.ok) {

    logger.warn('CompsAPI sold lookup was unsuccessful', { status: response.status });

    if ([401, 403].includes(response.status)) throw new HttpsError('failed-precondition', 'The sold-price service credentials need attention.');

    if (response.status === 429) throw new HttpsError('resource-exhausted', 'The sold-price lookup limit was reached. Please try later.');

    throw new HttpsError('unavailable', 'The sold-price service is currently unavailable.');

  }

  let json;

  try { json = await response.json(); } catch (_) { throw new HttpsError('unavailable', 'Invalid sold-price response.'); }

  if (!json || json.ok !== true || !Array.isArray(json.items)) {

    throw new HttpsError('unavailable', 'Incomplete sold-price response.');

  }

  return json;

}



exports.lookupCompsSealedSoldPrices = onCall({

  region: REGION,

  secrets: [COMPSAPI_KEY],

  timeoutSeconds: 70,

  memory: '256MiB',

}, async (request) => {

  if (!request.auth || !request.auth.uid) {

    throw new HttpsError('unauthenticated', 'Please sign in before checking sold prices.');

  }

  const product = productFromRequest(request.data || {});

  const quantity = Math.min(9999, Math.max(1, Math.floor(Number(request.data && request.data.quantity) || 1)));

  const ref = db.collection(CACHE_COLLECTION).doc(cacheKey(product));

  let result = await cachedLookup(ref);

  const cached = result !== null;

  if (!result) {

    const key = clean(COMPSAPI_KEY.value());

    if (!key) throw new HttpsError('failed-precondition', 'CompsAPI has not been configured yet.');

    const query = searchQuery(product);

    const payload = await getComps(key, query);

    result = summarise(parseSales(payload, product), product, query);

    await writeCache(ref, result);

    logger.info('Verified UK sold-price lookup completed', {

      productType: product.type, saleCount: result.saleCount,

      // Do not log the secret or user-specific collection data.

    });

  }

  return {

    ...result,

    cached,

    quantity,

    estimatedTotalValue: result.averageSoldPrice === null ? null : roundMoney(result.averageSoldPrice * quantity),

  };

});
