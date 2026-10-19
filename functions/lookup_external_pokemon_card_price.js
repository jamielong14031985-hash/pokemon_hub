// PocketChase exact-card pricing.

// Prefers recent eBay sold prices and only falls back to JustTCG when the

// provider card matches the exact name, set and collector number.



const { onCall, HttpsError } = require('firebase-functions/v2/https');

const { defineSecret } = require('firebase-functions/params');

const { logger } = require('firebase-functions');

const admin = require('firebase-admin');



if (!admin.apps.length) admin.initializeApp();



const db = admin.firestore();

const JUSTTCG_API_KEY = defineSecret('JUSTTCG_API_KEY');

const EBAY_CLIENT_ID = defineSecret('EBAY_CLIENT_ID');

const EBAY_CLIENT_SECRET = defineSecret('EBAY_CLIENT_SECRET');



const REGION = 'europe-west2';

const CACHE_COLLECTION = 'external_card_price_cache';

const JUSTTCG_URL = 'https://api.justtcg.com/v1/cards';

const EBAY_TOKEN_URL = 'https://api.ebay.com/identity/v1/oauth2/token';

const EBAY_SOLD_URL =

  'https://api.ebay.com/buy/marketplace_insights/v1_beta/item_sales/search';

const EBAY_SCOPE =

  'https://api.ebay.com/oauth/api_scope https://api.ebay.com/oauth/api_scope/buy.marketplace.insights';



const SUCCESS_CACHE_MS = 12 * 60 * 60 * 1000;

const NO_MATCH_CACHE_MS = 60 * 60 * 1000;

const CACHE_VERSION = 'confidence_pricing_v3_30th_20261013';
// Only 30th Celebration requests use a fresh cache namespace for diagnosis.
// Other sets keep their existing cache and API quota behaviour.
const THIRTY_DIAGNOSTIC_CACHE_VERSION = 'confidence_pricing_v9_30th_precision_20261014';

function createPriceDiagnostic(target) {
  return {
    version: '20261014-precision-v9',
    group: target.thirtyGroup || 'other',
    requestedNumber: target.displayNumber,
    ebay: {
      status: 'not_checked',
      httpStatus: null,
      results: 0,
      titleMatches: 0,
      validCurrencyPrices: 0,
    },
    justTcg: {
      status: 'not_checked',
      setLookups: [],
      eligibleSets: 0,
      cardLookups: [],
      candidates: 0,
      identityMatches: 0,
      // Aggregate safe diagnostics only: never write API keys or card listing payloads.
      matchChecks: {
        setMatches: 0,
        nameMatches: 0,
        numberMatches: 0,
        setAndNameMatches: 0,
        setNameNumberMatches: 0,
      },
      // Only limited public card metadata; never API keys, tokens or full payloads.
      candidateSamples: {
        matchingSet: [],
        matchingName: [],
        matchingNumber: [],
      },
    },
  };
}

function diagnosticNoMatch(target, result, diagnostic, cacheKey) {
  if (!target.isThirty || result.found) return result;
  const diagnosed = { ...result, diagnostic };
  // Log only status codes and counts, never API credentials, tokens, or raw listings.
  logger.info('30th card pricing diagnostic', { cacheKey, diagnostic });
  return diagnosed;
}




const MARKETPLACES = {

  UK: { id: 'EBAY_GB', country: 'GB', currency: 'GBP' },

  US: { id: 'EBAY_US', country: 'US', currency: 'USD' },

  IE: { id: 'EBAY_IE', country: 'IE', currency: 'EUR' },

  CA: { id: 'EBAY_CA', country: 'CA', currency: 'CAD' },

  AU: { id: 'EBAY_AU', country: 'AU', currency: 'AUD' },

};



let ebayToken = '';

let ebayTokenExpiresAtMs = 0;

// Avoid spending API quota rediscovering a new release's provider set IDs.
const justTcgSetCache = new Map();
const SET_CACHE_MS = 6 * 60 * 60 * 1000;



function clean(value) {

  return String(value || '').trim();

}



function normalise(value) {

  return clean(value)

    .normalize('NFKD')

    .replace(/[\u0300-\u036f]/g, '')

    .toLowerCase()

    .replace(/&/g, 'and')

    .replace(/[^a-z0-9]+/g, ' ')

    .replace(/\s+/g, ' ')

    .trim();

}



function normaliseNumber(value) {

  const first = clean(value).toLowerCase().split('/')[0];

  return first.replace(/[^a-z0-9]+/g, '').replace(/^0+(\d)/, '$1');

}



function safeCacheId(value) {

  return clean(value)

    .toLowerCase()

    .replace(/[^a-z0-9_-]+/g, '_')

    .replace(/_+/g, '_')

    .replace(/^_|_$/g, '')

    .substring(0, 1200) || 'unknown';

}



function numberValue(value) {

  if (typeof value === 'number' && Number.isFinite(value)) return value;

  const parsed = Number(clean(value).replace(/[^0-9.-]+/g, ''));

  return Number.isFinite(parsed) ? parsed : 0;

}



function setAliases(setName) {

  const raw = clean(setName);

  const aliases = new Set([raw]);

  raw.split(/[:\\-–—]+/).map(clean).filter(Boolean).forEach((part) => aliases.add(part));

  const lower = normalise(raw);

  if (lower.includes('30th celebration')) {

    aliases.add('30th Celebration');

    // Main and Classic are distinct products; never treat their prices as interchangeable.

  }

  if (lower.includes('ascended heroes')) aliases.add('Ascended Heroes');

  if (lower.includes('surging sparks')) aliases.add('Surging Sparks');

  return [...aliases].filter(Boolean).map(normalise);

}



function titleHasCardNumber(title, number) {

  if (!number) return false;

  const escaped = number.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  return new RegExp(`(^|[^a-z0-9])0*${escaped}([^a-z0-9]|$)`, "i").test(title);

}



function containsAlias(value, aliases) {

  const text = normalise(value);

  return aliases.some((alias) => alias && (text.includes(alias) || alias.includes(text)));

}



function excludedSoldTitle(title) {

  const text = normalise(title);

  const blocked = [

    'psa', 'bgs', 'cgc', 'ace graded', 'graded', 'slab', 'proxy', 'custom',

    'metal card', 'digital', 'code card', 'bundle', 'job lot', 'collection lot',

    'set of', 'pack', 'booster', 'box', 'etb', 'damaged', 'poor condition',

    'creased', 'crease', 'reprint', 'fake', 'replica', 'gold card', 'oversized',

    'jumbo', 'world championship', 'deck only', 'complete set', 'mystery',

  ];

  return blocked.some((term) => text.includes(term));

}



function exactSoldTitleMatch(title, target) {

  if (target.isThirty) return exactThirtySoldTitleMatch(title, target);

  const text = normalise(title);

  if (!text.includes(target.name)) return false;

  if (!titleHasCardNumber(clean(title), target.number)) return false;

  if (!containsAlias(title, target.setAliases)) return false;

  return !excludedSoldTitle(title);

}



function itemSetName(item) {

  const explicitName = clean(item.set_name || item.setName || item.expansionName || item.productSet);
  if (explicitName) return explicitName;

  const set = item.set || item.setInfo || item.expansion;

  if (typeof set === 'string') return clean(set);

  if (set && typeof set === 'object') {

    return clean(set.name || set.setName || set.title || set.code || set.id);

  }

  return clean(item.set_name || item.setName || item.expansionName || item.productSet);

}



function itemNumber(item) {

  return clean(item.number || item.cardNumber || item.collectorNumber ||

    item.collector_number || item.displayNumber || item.localId);

}



function exactProviderMatch(item, target) {

  if (target.isThirty) return exactThirtyProviderMatch(item, target);

  const itemName = normalise(item.name || item.cardName || item.title);

  const itemSet = itemSetName(item);

  const itemNo = normaliseNumber(itemNumber(item));

  return itemName === target.name &&

    itemNo === target.number &&

    containsAlias(itemSet, target.setAliases);

}



// The PocketChase 30th binder combines cards from several physical sets.
// The app passes a combined setName, but CC/MEP/MEE/RGB numbers are NOT main-set cards.
// These rules intentionally reject uncertain matches rather than display wrong prices.
function isThirtyCelebration({ displaySetName, setId, cardId }) {
  const label = normalise(displaySetName);
  const id = clean(setId).toLowerCase();
  const card = clean(cardId).toLowerCase();
  return label.includes('30th celebration') || label.includes('30th anniversary') ||
    ['30th', '30th-c', 'me55', 'me55c'].includes(id) ||
    /^(30th|me55|me55c)[-_:]/.test(card);
}

function thirtyGroup(data) {
  const number = clean(data.displayNumber).toUpperCase().replace(/\s+/g, '');
  if (/^CC\d+/.test(number) || clean(data.setId).toLowerCase() === 'me55c') return 'classic';
  if (/^MEP\d+/.test(number)) return 'promo';
  if (/^MEE\d+/.test(number)) return 'energy';
  if (/^[RGB]\/RGB$/.test(number)) return 'rgb';
  return 'main';
}

function isPokemonCenter(value) {
  const text = normalise(value);
  return text.includes('pokemon center') || text.includes('pokemon centre') ||
    text.includes('pc stamped');
}

function isThirtyProviderSet(item, target) {
  // JustTCG v1 has both set_name (display) and set (slug).
  const label = normalise([itemSetName(item), item.set, item.expansion].filter(Boolean).join(' '));
  const hasThirty = /\b(30th|thirtieth)\b/.test(label) &&
    (label.includes('celebration') || label.includes('anniversary'));
  const hasClassic = label.includes('classic collection') ||
    /\b(me55c|30th c)\b/.test(label);
  const hasPromos = /\bmep\b/.test(label) ||
    (label.includes('mega evolution') && label.includes('black star promo'));
  const hasEnergy = /\bmee\b/.test(label) ||
    label.includes('mega evolution energy');
  const providerNo = clean(itemNumber(item)).toUpperCase().replace(/\s+/g, '');
  if (target.thirtyGroup === 'classic') {
    return (hasThirty && hasClassic) ||
      (hasThirty && /^CC\d+/.test(providerNo));
  }
  if (target.thirtyGroup === 'promo') {
    return hasPromos || (hasThirty && /^MEP\d+/.test(providerNo));
  }
  if (target.thirtyGroup === 'energy') {
    return hasEnergy || (hasThirty && /^MEE\d+/.test(providerNo));
  }
  // Main/RGB: do not accept Classic, promo, or energy results.
  return hasThirty && !hasClassic && !hasPromos && !hasEnergy;
}

function thirtyNumberMatch(item, target) {
  const provider = normaliseNumber(itemNumber(item));
  if (!provider) return false;
  const expected = target.number;
  if (provider === expected) return true;
  if (target.thirtyGroup === 'classic') {
    // CC001 is the *binder slot*, not necessarily the printed collector number.
    // The merged binder preserves the official source card ID, e.g. me55c-4
    // for 30th Celebration Classic Charizard whose printed number is 4/102.
    // Require the separate exact set + exact name checks before valuing it.
    const officialSourceId = /^me55c[-_:]0*(\d+)$/i.exec(clean(target.cardId));
    if (officialSourceId) {
      return provider === normaliseNumber(officialSourceId[1]);
    }
    // Certain Mega EX Classic Collection entries retain an 'm' on the
    // catalogue source ID (e.g. me55c-106m), while JustTCG uses the physical
    // printed number (106/160). Only strip this suffix for a *Mega-prefixed*
    // card from the independently verified 30th Classic Collection. The
    // complete matcher also requires the correct set and exact Mega name.
    const megaSourceId = /^me55c[-_:]0*(\d+)m$/i.exec(clean(target.cardId));
    if (megaSourceId && target.name.startsWith('m ')) {
      return provider === normaliseNumber(megaSourceId[1]);
    }
    // If the official source ID is missing, a binder slot (CC018) is not
    // interchangeable with the source card's printed number (94/102).
    // Only accept an exact labelled CC identifier, never a guessed ordinal.
    return provider === expected;
  }
  if (target.thirtyGroup === 'promo') {
    // PocketChase displays MEP094; JustTCG can use 094 within the MEP set.
    const bare = expected.replace(/^mep/, '').replace(/pc$/, '');
    return provider === bare.replace(/^0+(\d)/, '$1') || provider === bare;
  }
  if (target.thirtyGroup === 'energy') {
    const bare = expected.replace(/^mee/, '');
    return provider === bare.replace(/^0+(\d)/, '$1') || provider === bare;
  }
  if (target.thirtyGroup === 'rgb') {
    return provider === expected.slice(0, 1);
  }
  return false;
}

// JustTCG sometimes adds a *card-type suffix* that PocketChase's official
// source catalogue leaves out (e.g. Gengar (Prime), Palkia (LV.X)).
// Strip only these known type annotations, never important prefixes such as
// Dark, Light, Shining, Mega, or suffixes such as ex/GX/V/VMAX.
// This is used ONLY for Classic Collection after an independent exact set and
// printed-number check has passed. It cannot price a similarly named base card.
function classicBaseName(value) {
  const full = normalise(value);
  const withoutType = full.replace(/\s+(?:prime|lv\s*x|level\s*x|legend)$/, '').trim();
  return withoutType || full;
}

function thirtyNameMatch(item, target) {
  const providerName = normalise(item.name || item.cardName || item.title);
  if (!providerName) return false;
  if (providerName === target.name) return true;
  // In the anniversary RGB subset, JustTCG calls the three Mew printings
  // 'Mew - R/RGB', 'Mew - G/RGB', and 'Mew - B/RGB'. PocketChase displays
  // the common card name 'Mew'. Accept the *matching colour suffix only*;
  // the caller separately verifies both the 30th main set and R/G/B number.
  if (target.thirtyGroup === 'rgb' && target.name === 'mew') {
    const colour = target.number.slice(0, 1).toLowerCase();
    if (/^[rgb]$/.test(colour) && providerName === `mew ${colour} rgb`) {
      return true;
    }
  }
  if (target.thirtyGroup === 'classic') {
    const expectedBase = classicBaseName(target.name);
    const providerBase = classicBaseName(providerName);
    if (expectedBase && providerBase === expectedBase &&
        (expectedBase !== target.name || providerBase !== providerName)) {
      return true;
    }
  }
  if (target.thirtyGroup === 'energy' && providerName === `basic ${target.name}`) {
    return true;
  }
  if (target.thirtyGroup === 'promo' && target.isPokemonCenter) {
    return providerName === target.name.replace(/ pokemon center$/, '').trim();
  }
  return false;
}

function exactThirtyProviderMatch(item, target) {
  if (!isThirtyProviderSet(item, target) || !thirtyNumberMatch(item, target) ||
      !thirtyNameMatch(item, target)) return false;
  const descriptiveText = [item.name, item.id, item.details, item.rarity].join(' ');
  if (target.thirtyGroup === 'promo') {
    // A Pokemon Center stamped version is never valued using an ordinary copy.
    const marked = isPokemonCenter(descriptiveText);
    if (target.isPokemonCenter && !marked) {
      // Some providers put the stamp exclusively on the variant instead.
      return [item.variants].flat().some((v) => isPokemonCenter([
        v && v.printing, v && v.name, v && v.id,
      ].join(' ')));
    }
    if (!target.isPokemonCenter && marked) return false;
  }
  return true;
}

function exactThirtySoldTitleMatch(title, target) {
  const text = normalise(title);
  if (!text.includes(target.name.replace(/ pokemon center$/, '').trim())) return false;
  if (excludedSoldTitle(title)) return false;
  const hasThirty = /\b(30th|thirtieth)\b/.test(text) &&
    (text.includes('celebration') || text.includes('anniversary'));
  if (target.thirtyGroup === 'classic') {
    const bare = target.displayNumber.replace(/^CC/i, '').replace(/^0+(\d)/, '$1');
    return hasThirty && text.includes('classic') &&
      (titleHasCardNumber(title, target.displayNumber) || titleHasCardNumber(title, bare));
  }
  if (target.thirtyGroup === 'promo') {
    const base = target.displayNumber.replace(/^MEP/i, '').replace(/PC$/i, '');
    const marked = isPokemonCenter(text);
    return (text.includes('mep') || text.includes('mega evolution black star')) &&
      (titleHasCardNumber(title, base) || titleHasCardNumber(title, target.displayNumber)) &&
      marked === target.isPokemonCenter;
  }
  if (target.thirtyGroup === 'energy') {
    return text.includes('mee') && titleHasCardNumber(title, target.displayNumber);
  }
  if (target.thirtyGroup === 'rgb') {
    return hasThirty && text.includes('rgb') && text.includes(target.displayNumber.toLowerCase());
  }
  return hasThirty && !text.includes('classic collection') &&
    !text.includes('black star promo') && !text.includes('mep') &&
    titleHasCardNumber(title, target.number);
}

function flattenObjects(value) {

  if (!value) return [];

  if (Array.isArray(value)) return value.filter((item) => item && typeof item === 'object');

  if (typeof value !== 'object') return [];

  const result = [];

  for (const [printing, child] of Object.entries(value)) {

    if (Array.isArray(child)) {

      child.filter((item) => item && typeof item === 'object')

        .forEach((item) => result.push({ printing, ...item }));

    } else if (child && typeof child === 'object') {

      result.push({ printing, ...child });

    }

  }

  return result;

}



function firstPrice(value) {

  if (!value || typeof value !== 'object') return 0;

  for (const key of ['marketPrice', 'market', 'price', 'average', 'avg', 'mid', 'lastSold']) {

    const amount = numberValue(value[key]);

    if (amount > 0) return amount;

  }

  return 0;

}



function bestJustTcgVariant(card) {

  const variants = [

    ...flattenObjects(card.variants),

    ...flattenObjects(card.prices),

    ...flattenObjects(card.marketPrices),

    ...flattenObjects(card.conditions),

  ];

  if (firstPrice(card) > 0) variants.push({ ...card, price: firstPrice(card) });

  return variants

    .map((variant) => ({ variant, amount: firstPrice(variant) }))

    .filter((entry) => entry.amount > 0)

    .sort((a, b) => {

      const rank = (entry) => {

        const condition = normalise(entry.variant.condition || entry.variant.grade);

        const printing = normalise(entry.variant.printing || entry.variant.finish);

        return (condition.includes('near mint') || condition === 'nm' ? 10 : 0) +

          (printing === 'normal' || printing === 'regular' ? 3 : 0);

      };

      return rank(b) - rank(a);

    })[0] || null;

}



function extractArray(payload) {

  if (Array.isArray(payload)) return payload;

  if (!payload || typeof payload !== 'object') return [];

  for (const value of [payload.itemSales, payload.data, payload.results, payload.cards]) {

    if (Array.isArray(value)) return value;

  }

  if (payload.data && Array.isArray(payload.data.cards)) return payload.data.cards;

  return [];

}



async function getEbayToken(clientId, clientSecret) {

  if (ebayToken && ebayTokenExpiresAtMs > Date.now() + 60000) return ebayToken;

  const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

  const response = await fetch(EBAY_TOKEN_URL, {

    method: 'POST',

    headers: {

      Authorization: `Basic ${credentials}`,

      'Content-Type': 'application/x-www-form-urlencoded',

    },

    body: new URLSearchParams({ grant_type: 'client_credentials', scope: EBAY_SCOPE }).toString(),

  });

  if (!response.ok) throw new Error(`eBay token HTTP ${response.status}`);

  const payload = await response.json();

  ebayToken = clean(payload.access_token);

  ebayTokenExpiresAtMs = Date.now() + Math.max(60, numberValue(payload.expires_in)) * 1000;

  return ebayToken;

}



function soldPrice(item) {

  const price = item.lastSoldPrice || item.soldPrice || item.price;

  return {

    amount: numberValue(price && price.value),

    currency: clean(price && price.currency).toUpperCase(),

  };

}



function removePriceOutliers(values) {

  if (values.length < 4) return values;

  const sorted = [...values].sort((a, b) => a - b);

  const median = sorted.length % 2 === 1

    ? sorted[Math.floor(sorted.length / 2)]

    : (sorted[(sorted.length / 2) - 1] + sorted[sorted.length / 2]) / 2;

  const deviations = sorted.map((value) => Math.abs(value - median)).sort((a, b) => a - b);

  const mad = deviations.length % 2 === 1

    ? deviations[Math.floor(deviations.length / 2)]

    : (deviations[(deviations.length / 2) - 1] + deviations[deviations.length / 2]) / 2;

  if (mad > 0) {

    const robust = sorted.filter((value) => (0.6745 * Math.abs(value - median) / mad) <= 3.5);

    if (robust.length >= Math.min(3, sorted.length)) return robust;

  }

  const percentile = (p) => sorted[Math.floor((sorted.length - 1) * p)];

  const q1 = percentile(0.25);

  const q3 = percentile(0.75);

  const iqr = q3 - q1;

  return sorted.filter((value) => value >= q1 - (1.5 * iqr) && value <= q3 + (1.5 * iqr));

}



function medianValue(values) {

  if (!values.length) return 0;

  const sorted = [...values].sort((a, b) => a - b);

  const middle = Math.floor(sorted.length / 2);

  return sorted.length % 2 === 1

    ? sorted[middle]

    : (sorted[middle - 1] + sorted[middle]) / 2;

}



function soldConfidence(values) {

  if (!values.length) return 'unavailable';

  const median = medianValue(values);

  const spreadRatio = median > 0

    ? (Math.max(...values) - Math.min(...values)) / median

    : Number.POSITIVE_INFINITY;

  if (values.length >= 8 && spreadRatio <= 0.35) return 'high';

  if (values.length >= 3 && spreadRatio <= 0.75) return 'medium';

  return 'low';

}



async function lookupEbaySold(target, marketplaceCode, clientId, clientSecret, diagnostic = null) {

  const diag = diagnostic && diagnostic.ebay;
  if (!clientId || !clientSecret) {
    if (diag) diag.status = 'credentials_missing';
    return null;
  }
  if (diag) diag.status = 'request_started';

  const marketplace = MARKETPLACES[marketplaceCode] || MARKETPLACES.UK;

  let token;
  try {
    token = await getEbayToken(clientId, clientSecret);
  } catch (error) {
    if (diag) {
      diag.status = 'token_request_failed';
      const matchedStatus = /eBay token HTTP (\d+)/.exec(String(error && error.message));
      if (matchedStatus) diag.httpStatus = Number(matchedStatus[1]);
    }
    throw error;
  }

  const query = [target.displayName, target.displaySetName, target.displayNumber, 'pokemon card']

    .filter(Boolean).join(' ');

  const url = new URL(EBAY_SOLD_URL);

  url.searchParams.set('q', query);

  url.searchParams.set('limit', '50');

  const response = await fetch(url.toString(), {

    headers: {

      Authorization: `Bearer ${token}`,

      accept: 'application/json',

      'X-EBAY-C-MARKETPLACE-ID': marketplace.id,

      'X-EBAY-C-ENDUSERCTX': `contextualLocation=country%3D${marketplace.country}`,

    },

  });

  if (!response.ok) {

    // Marketplace Insights access is restricted for some eBay applications.

    // Fall back to strict JustTCG matching, never to a loose card match.

    logger.warn('eBay sold lookup unavailable.', { status: response.status });
    if (diag) {
      diag.httpStatus = response.status;
      diag.status = response.status === 401 || response.status === 403
        ? 'sold_api_access_denied' : 'sold_api_http_error';
    }
    return null;

  }

  const items = extractArray(await response.json());
  const matchedTitles = items.filter((item) => exactSoldTitleMatch(clean(item.title), target));
  const sales = matchedTitles
    .map(soldPrice)
    .filter((price) => price.amount > 0 && price.currency === marketplace.currency);

  if (diag) {
    diag.httpStatus = response.status;
    diag.results = items.length;
    diag.titleMatches = matchedTitles.length;
    diag.validCurrencyPrices = sales.length;
  }

  const filtered = removePriceOutliers(sales.map((sale) => sale.amount));

  if (!filtered.length) {
    if (diag) {
      diag.status = items.length === 0 ? 'no_sold_results'
        : matchedTitles.length === 0 ? 'title_filter_rejected_all'
          : 'no_valid_currency_prices';
    }
    return null;
  }
  if (diag) diag.status = 'matched';

  // Median is deliberately used instead of a simple average. One unusually

  // high sale or an accepted-offer listing should not inflate the app value.

  const median = medianValue(filtered);

  return {

    found: true,

    amount: Number(median.toFixed(2)),

    lowAmount: Number(Math.min(...filtered).toFixed(2)),

    highAmount: Number(Math.max(...filtered).toFixed(2)),

    currencyCode: marketplace.currency,

    source: `eBay sold median (${filtered.length})`,

    soldCount: filtered.length,

    confidence: soldConfidence(filtered),

    pricingMethod: 'sold_median',

    lastUpdatedMs: Date.now(),

  };

}



async function justTcgCardSearch(apiKey, query, providerSetId = '', diagnostic = null) {
  const url = new URL(JUSTTCG_URL);
  url.searchParams.set('game', 'pokemon');
  url.searchParams.set('q', query);
  if (providerSetId) url.searchParams.set('set', providerSetId);
  url.searchParams.set('condition', 'NM');
  url.searchParams.set('limit', '20');
  const response = await fetch(url.toString(), {
    headers: { 'x-api-key': apiKey, accept: 'application/json' },
  });
  const entry = { scope: providerSetId ? 'set_filtered' : 'unfiltered',
    httpStatus: response.status, candidates: 0 };
  if (diagnostic) diagnostic.justTcg.cardLookups.push(entry);
  if (response.status === 429) {
    throw new HttpsError('resource-exhausted', 'JustTCG rate limit exceeded.');
  }
  if (!response.ok) {
    logger.warn('JustTCG card lookup unavailable.', { status: response.status });
    return [];
  }
  const cards = extractArray(await response.json());
  entry.candidates = cards.length;
  return cards;
}

async function lookupJustTcgSets(apiKey, query, diagnostic = null) {
  const cached = justTcgSetCache.get(query);
  if (cached && cached.expiresAtMs > Date.now()) {
    if (diagnostic) diagnostic.justTcg.setLookups.push({ status: 'cached',
      resultCount: cached.sets.length });
    return cached.sets;
  }
  const url = new URL('https://api.justtcg.com/v1/sets');
  url.searchParams.set('game', 'pokemon');
  url.searchParams.set('q', query);
  const response = await fetch(url.toString(), {
    headers: { 'x-api-key': apiKey, accept: 'application/json' },
  });
  const entry = { httpStatus: response.status, resultCount: 0 };
  if (diagnostic) diagnostic.justTcg.setLookups.push(entry);
  if (response.status === 429) {
    throw new HttpsError('resource-exhausted', 'JustTCG rate limit exceeded.');
  }
  if (!response.ok) {
    logger.warn('JustTCG set catalogue lookup unavailable.', { status: response.status });
    return [];
  }
  const sets = extractArray(await response.json());
  entry.resultCount = sets.length;
  justTcgSetCache.set(query, { sets, expiresAtMs: Date.now() + SET_CACHE_MS });
  return sets;
}

function chooseThirtyVariant(card, target) {
  const entries = [
    ...flattenObjects(card.variants),
    ...flattenObjects(card.prices),
    ...flattenObjects(card.marketPrices),
    ...flattenObjects(card.conditions),
  ];
  if (firstPrice(card) > 0) entries.push({ ...card, price: firstPrice(card) });
  const matching = entries.filter((variant) => {
    const mark = isPokemonCenter([variant.printing, variant.name, variant.id].join(' ')) ||
      isPokemonCenter([card.name, card.id, card.details, card.rarity].join(' '));
    return target.thirtyGroup !== 'promo' || mark === target.isPokemonCenter;
  });
  return bestJustTcgVariant({ variants: matching });
}

function justTcgResult(card, target) {
  if (!exactProviderMatch(card, target)) return null;
  const best = target.isThirty ? chooseThirtyVariant(card, target) : bestJustTcgVariant(card);
  if (!best) return null;
  return {
    found: true,
    amount: best.amount,
    currencyCode: clean(best.variant.currency || best.variant.currencyCode || 'USD') || 'USD',
    source: 'JustTCG exact match',
    soldCount: 0,
    confidence: 'reference',
    pricingMethod: 'provider_reference',
    providerCardId: clean(card.id || card.uuid),
    providerVariantId: clean(best.variant.id || best.variant.uuid),
    lastUpdatedMs: Date.now(),
  };
}

function shortPublicCardField(value, maxLength = 90) {
  if (typeof value === 'object' && value !== null) {
    value = value.name || value.title || value.id || value.setName || '';
  }
  return clean(value).substring(0, maxLength);
}

function recordThirtyCandidateSample(diagnostic, card, matches) {
  if (!diagnostic || !diagnostic.justTcg || !diagnostic.justTcg.candidateSamples) return;
  const samples = diagnostic.justTcg.candidateSamples;
  const summary = {
    name: shortPublicCardField(card.name || card.cardName || card.title),
    setName: shortPublicCardField(itemSetName(card)),
    setId: shortPublicCardField(card.set),
    number: shortPublicCardField(itemNumber(card), 40),
    setMatch: matches.setMatch,
    nameMatch: matches.nameMatch,
    numberMatch: matches.numberMatch,
  };
  if (matches.setMatch && samples.matchingSet.length < 3) samples.matchingSet.push(summary);
  if (matches.nameMatch && samples.matchingName.length < 3) samples.matchingName.push(summary);
  if (matches.numberMatch && samples.matchingNumber.length < 3) samples.matchingNumber.push(summary);
}

function inspectJustTcgCandidates(cards, target, diagnostic) {
  if (diagnostic) diagnostic.justTcg.candidates += cards.length;
  for (const card of cards) {
    if (diagnostic && target.isThirty) {
      const checks = diagnostic.justTcg.matchChecks;
      const setMatch = isThirtyProviderSet(card, target);
      const nameMatch = thirtyNameMatch(card, target);
      const numberMatch = thirtyNumberMatch(card, target);
      recordThirtyCandidateSample(diagnostic, card, { setMatch, nameMatch, numberMatch });
      if (setMatch) checks.setMatches++;
      if (nameMatch) checks.nameMatches++;
      if (numberMatch) checks.numberMatches++;
      if (setMatch && nameMatch) checks.setAndNameMatches++;
      if (setMatch && nameMatch && numberMatch) checks.setNameNumberMatches++;
    }
    if (diagnostic && exactProviderMatch(card, target)) {
      diagnostic.justTcg.identityMatches++;
    }
    const result = justTcgResult(card, target);
    if (result) return result;
  }
  return null;
}

async function lookupJustTcg(target, apiKey, diagnostic = null) {
  const diag = diagnostic && diagnostic.justTcg;
  if (!apiKey) {
    if (diag) diag.status = 'key_missing';
    return null;
  }
  if (diag) diag.status = 'search_started';
  if (!target.isThirty) {
    // Keep all other sets using their original search route.
    const query = [target.displayName, target.displaySetName, target.displayNumber]
      .filter(Boolean).join(' ');
    const result = inspectJustTcgCandidates(
      await justTcgCardSearch(apiKey, query, '', diagnostic), target, diagnostic);
    if (diag) diag.status = result ? 'matched' : diag.identityMatches > 0
      ? 'no_priced_variant' : diag.candidates > 0
        ? 'identity_filter_rejected_all' : 'no_cards_returned';
    return result;
  }

  // New-release identifiers differ across PocketChase, TCGdex and JustTCG.
  // Ask JustTCG for its actual set ID rather than assuming 'me55' is the same ID.
  const setQuery = target.thirtyGroup === 'promo' ? 'black star promos' :
    target.thirtyGroup === 'energy' ? 'mega evolution energy' : '30th';
  let providerSets = await lookupJustTcgSets(apiKey, setQuery, diagnostic);
  if (!providerSets.length && setQuery === '30th') {
    providerSets = await lookupJustTcgSets(apiKey, 'anniversary', diagnostic);
  }
  const eligibleSetIds = providerSets
    .filter((set) => isThirtyProviderSet({ set_name: set.name, set: set.id }, target))
    .map((set) => clean(set.id)).filter(Boolean).slice(0, 3);

  if (diag) diag.eligibleSets = eligibleSetIds.length;

  const visited = new Set();
  const searchName = target.thirtyGroup === 'promo' && target.isPokemonCenter
    ? target.displayName.replace(/\s*\[?Pok[eé]mon Center\]?/i, '').trim()
    : target.displayName;
  for (const setId of [...eligibleSetIds, '']) {
    const searchKey = `${setId}|${searchName}`;
    if (visited.has(searchKey)) continue;
    visited.add(searchKey);
    const candidates = await justTcgCardSearch(apiKey, searchName, setId, diagnostic);
    const result = inspectJustTcgCandidates(candidates, target, diagnostic);
    if (result) {
      if (diag) diag.status = 'matched';
      return result;
    }
  }
  // Some provider records use a type-qualified name (Prime / LV.X) and do
  // not appear in a name-only query. Query the printed number within the
  // *verified 30th provider set* as a bounded fallback, then apply the same
  // independent name, set, and number filters. Never search by binder slot.
  if (eligibleSetIds.length && target.thirtyGroup === 'classic') {
    const fromSource = /^me55c[-_:]0*(\d+)$/i.exec(target.cardId);
    if (fromSource) {
      const printedNumber = String(Number(fromSource[1]));
      for (const setId of eligibleSetIds.slice(0, 1)) {
        const candidates = await justTcgCardSearch(apiKey, printedNumber, setId, diagnostic);
        const result = inspectJustTcgCandidates(candidates, target, diagnostic);
        if (result) {
          if (diag) diag.status = 'matched';
          return result;
        }
      }
    }
  }
  if (diag) {
    const providerError = diag.cardLookups.some((entry) => entry.httpStatus >= 400) ||
      diag.setLookups.some((entry) => entry.httpStatus >= 400);
    diag.status = diag.identityMatches > 0 ? 'no_priced_variant'
      : diag.candidates > 0 ? 'identity_filter_rejected_all'
        : providerError ? 'provider_http_error' : 'no_cards_returned';
  }
  return null;
}

async function readCache(ref) {

  try {

    const snapshot = await ref.get();

    if (!snapshot.exists) return null;

    const data = snapshot.data() || {};

    return Number(data.expiresAtMs || 0) > Date.now() ? data.response || null : null;

  } catch (_) {

    return null;

  }

}



async function writeCache(ref, response, ttlMs) {

  try {

    await ref.set({ response, updatedAtMs: Date.now(), expiresAtMs: Date.now() + ttlMs },

      { merge: true });

  } catch (_) {}

}




// Whole-set audit, isolated from normal card lookups. Do not broaden card identity.
// Free-plan default: at most 20 provider cards per page; a higher plan can
// change these two settings in a future controlled deployment.
const THIRTY_AUDIT_PLAN = 'free';
const THIRTY_AUDIT_PLANS = {
  free: { pageSize: 20, dailyAuditBudget: 30 },
  starter: { pageSize: 100, dailyAuditBudget: 150 },
};
const AUDIT_CONFIG = THIRTY_AUDIT_PLANS[THIRTY_AUDIT_PLAN];
const AUDIT_PAGE_CACHE_MS = 12 * 60 * 60 * 1000;
const AUDIT_PAGE_COLLECTION = 'thirty_justtcg_set_pages_v1';
const AUDIT_USAGE_COLLECTION = 'thirty_justtcg_audit_quota';
const AUDIT_GROUPS = new Set(['main', 'classic', 'rgb', 'energy', 'promo']);
const THIRTY_SET_IDS = {
  main: 'me-30th-celebration-pokemon',
  classic: 'me-30th-celebration-classic-collection-pokemon',
  rgb: 'me-30th-celebration-pokemon',
};

function thirtyAuditTarget(card) {
  const displayName = clean(card.name);
  const displaySetName = clean(card.setName);
  const displayNumber = clean(card.number);
  if (!displayName || !displayNumber || !displaySetName || !clean(card.cardId)) return null;
  if (!isThirtyCelebration({ displaySetName, setId: card.setId, cardId: card.cardId })) return null;
  const target = {
    displayName, displaySetName, displayNumber,
    name: normalise(displayName), number: normaliseNumber(displayNumber),
    setAliases: setAliases(displaySetName), setId: clean(card.setId),
    cardId: clean(card.cardId), isThirty: true,
    isPokemonCenter: isPokemonCenter(displayName) || /PC$/i.test(displayNumber),
  };
  target.thirtyGroup = thirtyGroup(target);
  return target;
}

// Cache only the public, minimal data required to reuse exact matching.
// Large provider response histories are deliberately never stored in Firestore.
function compactAuditProviderCard(card) {
  return {
    id: clean(card.id || card.uuid),
    name: clean(card.name), set: clean(card.set),
    set_name: itemSetName(card), number: itemNumber(card),
    rarity: clean(card.rarity), details: clean(card.details).slice(0, 160),
    price: firstPrice(card), variants: flattenObjects(card.variants).slice(0, 35).map((v) => ({
      id: clean(v.id || v.uuid), name: clean(v.name),
      condition: clean(v.condition), printing: clean(v.printing),
      currency: clean(v.currency || v.currencyCode), price: firstPrice(v),
    })),
  };
}

async function reserveThirtyAuditRequest() {
  // Conservative *audit-only* budget; ordinary app price lookups share the
  // provider allowance and are NOT counted here. This is an extra safeguard,
  // not a claim that provider quota remains available.
  const day = new Date().toISOString().slice(0, 10);
  const ref = db.collection(AUDIT_USAGE_COLLECTION).doc(day);
  const allowed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = Number((snap.exists && snap.data().requests) || 0);
    if (count >= AUDIT_CONFIG.dailyAuditBudget) return false;
    tx.set(ref, { requests: count + 1, updatedAtMs: Date.now() }, { merge: true });
    return true;
  });
  if (!allowed) throw new HttpsError('resource-exhausted',
    'Free-plan audit safety budget reached today. Resume after 00:00 UTC.');
}

async function resolveThirtyAuditSetId(group, apiKey) {
  if (THIRTY_SET_IDS[group]) return THIRTY_SET_IDS[group];
  const query = group === 'energy' ? 'mega evolution energy' : 'black star promos';
  // Standard set discovery remains in place for the promo/energy catalogues.
  const sets = await lookupJustTcgSets(apiKey, query);
  const eligible = sets.filter((set) => isThirtyProviderSet(
    { set_name: set.name, set: set.id }, { thirtyGroup: group }));
  return eligible.length === 1 ? clean(eligible[0].id) : '';
}

async function readThirtyAuditPage(group, setId, offset, apiKey) {
  const pageSize = AUDIT_CONFIG.pageSize;
  const cacheGroup = group === 'rgb' ? 'main' : group;
  const key = safeCacheId(`set_page_v1|${cacheGroup}|${setId}|${pageSize}|${offset}`);
  const ref = db.collection(AUDIT_PAGE_COLLECTION).doc(key);
  const cached = await readCache(ref);
  if (cached) return { ...cached, fromCache: true };
  await reserveThirtyAuditRequest();
  const url = new URL(JUSTTCG_URL);
  url.searchParams.set('game', 'pokemon');
  url.searchParams.set('set', setId);
  url.searchParams.set('limit', String(pageSize));
  url.searchParams.set('offset', String(offset));
  url.searchParams.set('condition', 'NM');
  const response = await fetch(url.toString(), {
    headers: { 'x-api-key': apiKey, accept: 'application/json' },
  });
  if (response.status === 429) throw new HttpsError('resource-exhausted',
    'JustTCG rate limited the set audit. Pause and retry after the allowance resets.');
  if (!response.ok) throw new HttpsError('unavailable',
    `JustTCG returned HTTP ${response.status}; audit paused safely.`);
  const payload = await response.json();
  const cards = extractArray(payload).map(compactAuditProviderCard);
  const meta = payload && payload.meta || {};
  const more = typeof meta.hasMore === 'boolean' ? meta.hasMore : cards.length === pageSize;
  const answer = { cards, hasMore: more, nextOffset: offset + pageSize };
  // A cache-write failure should not create incorrect matches. A later
  // request might repeat one API call, which the audit budget still guards.
  await writeCache(ref, answer, AUDIT_PAGE_CACHE_MS);
  return { ...answer, fromCache: false };
}

async function lookupThirtyAuditPage(data) {
  const group = clean(data.group);
  const offset = Number(data.offset);
  if (!AUDIT_GROUPS.has(group) || !Number.isSafeInteger(offset) ||
      offset < 0 || offset > 500 || offset % AUDIT_CONFIG.pageSize !== 0) {
    throw new HttpsError('invalid-argument', 'Invalid 30th audit page.');
  }
  if (!Array.isArray(data.cards) || data.cards.length > 208) {
    throw new HttpsError('invalid-argument', 'Invalid audit checklist.');
  }
  const targets = data.cards.map(thirtyAuditTarget);
  if (targets.some((t) => !t || t.thirtyGroup !== group)) {
    throw new HttpsError('invalid-argument', 'Audit contains a card from another set.');
  }
  const apiKey = clean(JUSTTCG_API_KEY.value());
  if (!apiKey) throw new HttpsError('failed-precondition', 'JustTCG key not configured.');
  const setId = await resolveThirtyAuditSetId(group, apiKey);
  if (!setId) return { status: 'set_not_resolved', group, matches: [], hasMore: false };
  const page = await readThirtyAuditPage(group, setId, offset, apiKey);
  const matches = [];
  const counts = [];
  for (const target of targets) {
    let exactWithoutPrice = false;
    let names = 0, numbers = 0, sets = 0;
    let found = null;
    for (const item of page.cards) {
      if (isThirtyProviderSet(item, target)) sets++;
      if (thirtyNameMatch(item, target)) names++;
      if (thirtyNumberMatch(item, target)) numbers++;
      if (exactProviderMatch(item, target)) exactWithoutPrice = true;
      const price = justTcgResult(item, target);
      if (price) { found = price; break; }
    }
    if (found) matches.push({ cardId: target.cardId, price: found });
    counts.push({ cardId: target.cardId, sets, names, numbers,
      exactWithoutPrice: exactWithoutPrice && !found });
  }
  return { status: 'ok', group, matches, counts,
    hasMore: page.hasMore, nextOffset: page.nextOffset,
    cachedProviderPage: page.fromCache, providerCards: page.cards.length,
    pageSize: AUDIT_CONFIG.pageSize, plan: THIRTY_AUDIT_PLAN };
}

exports.lookupExternalPokemonCardPrice = onCall(

  {

    region: REGION,

    secrets: [JUSTTCG_API_KEY, EBAY_CLIENT_ID, EBAY_CLIENT_SECRET],

    timeoutSeconds: 35,

    memory: '256MiB',

  },

  async (request) => {

    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in first.');

    const data = request.data || {};
    if (data.mode === 'thirty_audit_page_v1') {
      return lookupThirtyAuditPage(data);
    }

    const displayName = clean(data.name);

    const displaySetName = clean(data.setName);

    const displayNumber = clean(data.number);

    if (!displayName || !displaySetName || !displayNumber) {

      return { found: false, reason: 'missing_card_identity' };

    }

    const target = {

      displayName,

      displaySetName,

      displayNumber,

      name: normalise(displayName),

      setAliases: setAliases(displaySetName),

      number: normaliseNumber(displayNumber),

      setId: clean(data.setId),

      cardId: clean(data.cardId),

      isThirty: isThirtyCelebration({ displaySetName, setId: data.setId, cardId: data.cardId }),

      isPokemonCenter: isPokemonCenter(displayName) || /PC$/i.test(displayNumber),

    };

    target.thirtyGroup = target.isThirty ? thirtyGroup(target) : '';

    const marketplaceCode = clean(data.marketplaceCode).toUpperCase() || 'UK';

    const cacheKey = safeCacheId([

      target.isThirty ? THIRTY_DIAGNOSTIC_CACHE_VERSION : CACHE_VERSION,
      marketplaceCode, clean(data.cardId), target.name,

      normalise(displaySetName), target.number,

    ].join('|'));

    const cacheRef = db.collection(CACHE_COLLECTION).doc(cacheKey);

    const cached = await readCache(cacheRef);

    if (cached) return { ...cached, cached: true };



    let result = null;
    const diagnostic = target.isThirty ? createPriceDiagnostic(target) : null;

    // Marketplace Insights is a restricted API and this project's access was
    // declined. For 30th Celebration cards, do not call it, retry OAuth, or
    // imply that a JustTCG reference value represents completed UK sales.
    // Preserve the existing route for other sets in this targeted update.
    if (target.isThirty) {
      diagnostic.ebay.status = 'skipped_unapproved_sold_api';
    } else {
      try {
        result = await lookupEbaySold(
          target,
          MARKETPLACES[marketplaceCode] ? marketplaceCode : 'UK',
          clean(EBAY_CLIENT_ID.value()),
          clean(EBAY_CLIENT_SECRET.value()),
          diagnostic,
        );
      } catch (error) {
        logger.warn('eBay sold price lookup failed.', { message: clean(error && error.message) });
      }
    }

    if (!result) {

      try {

        result = await lookupJustTcg(target, clean(JUSTTCG_API_KEY.value()), diagnostic);

      } catch (error) {

        if (error && error.code === 'resource-exhausted') {
          if (diagnostic) diagnostic.justTcg.status = 'rate_limited';
          return diagnosticNoMatch(target, { found: false, reason: 'rate_limited' },
            diagnostic, cacheKey);
        }
        if (diagnostic) diagnostic.justTcg.status = 'request_failed';
        logger.warn('JustTCG lookup failed.', { message: clean(error && error.message) });

      }

    }

    if (!result) result = { found: false, reason: 'no_exact_price_match' };
    result = diagnosticNoMatch(target, result, diagnostic, cacheKey);

    await writeCache(cacheRef, result, result.found ? SUCCESS_CACHE_MS : NO_MATCH_CACHE_MS);

    return result;

  },

);
