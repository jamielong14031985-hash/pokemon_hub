const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const REGION = "europe-west2";
const NOTIFICATION_CHANNEL_ID = "pocketchase_notifications";

const DEFAULT_CHECK_TIMEOUT_MS = 20000;
const POKEWALLET_API_KEY = defineSecret("POKEWALLET_API_KEY");

const DESKTOP_BROWSER_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  Accept:
    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
  "Accept-Language": "en-GB,en;q=0.9",
  "Cache-Control": "no-cache",
  Pragma: "no-cache",
  "Upgrade-Insecure-Requests": "1",
  "Sec-Fetch-Dest": "document",
  "Sec-Fetch-Mode": "navigate",
  "Sec-Fetch-Site": "none",
  "Sec-Fetch-User": "?1",
};

const MOBILE_BROWSER_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36",
  Accept:
    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
  "Accept-Language": "en-GB,en;q=0.9",
  "Cache-Control": "no-cache",
  Pragma: "no-cache",
  "Upgrade-Insecure-Requests": "1",
  "Sec-Fetch-Dest": "document",
  "Sec-Fetch-Mode": "navigate",
  "Sec-Fetch-Site": "none",
  "Sec-Fetch-User": "?1",
};

class ProductCheckError extends Error {
  constructor(message, checkStatus, httpStatus) {
    super(message);
    this.name = "ProductCheckError";
    this.checkStatus = checkStatus || "check_failed";
    this.httpStatus = httpStatus || 0;
  }
}

function cleanString(value) {
  return String(value || "").trim();
}

function cleanLower(value) {
  return cleanString(value).toLowerCase();
}

function stringList(value) {
  if (!Array.isArray(value)) return [];

  return value
    .map((item) => cleanString(item))
    .filter((item) => item.length > 0);
}

function normaliseUrl(url) {
  const raw = cleanString(url);

  if (!raw) return "";

  if (raw.startsWith("http://") || raw.startsWith("https://")) {
    return raw;
  }

  return `https://${raw}`;
}

function getHost(url) {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch (error) {
    return "";
  }
}

function buildBrowserHeaders(url, useMobileHeaders) {
  const host = getHost(url);
  const baseHeaders = useMobileHeaders
    ? MOBILE_BROWSER_HEADERS
    : DESKTOP_BROWSER_HEADERS;

  return {
    ...baseHeaders,
    ...(host ? { Referer: `https://${host}/` } : {}),
  };
}

function httpCheckStatus(status) {
  if (status === 401) return "shop_requires_authorisation";
  if (status === 403) return "shop_blocked_automatic_checking";
  if (status === 404) return "product_page_not_found";
  if (status === 429) return "shop_rate_limited_automatic_checking";
  if (status >= 500) return "shop_server_error";
  return "http_error";
}

function httpStatusMessage(status, statusText) {
  if (status === 401) return "Shop requires authorisation";
  if (status === 403) return "Shop blocked automatic checking";
  if (status === 404) return "Product page not found";
  if (status === 429) return "Shop rate limited automatic checking";
  if (status >= 500) return `Shop server error HTTP ${status}`;

  const cleanStatusText = cleanString(statusText);
  return cleanStatusText ? `HTTP ${status} ${cleanStatusText}` : `HTTP ${status}`;
}

function productCheckStatusFromError(error) {
  if (error instanceof ProductCheckError && error.checkStatus) {
    return error.checkStatus;
  }

  return "check_failed";
}

function productCheckMessageFromError(error) {
  if (error && error.message) {
    return String(error.message);
  }

  return String(error);
}

function buildStoreId(product) {
  const explicitStoreId = cleanString(product.storeId);

  if (explicitStoreId) return explicitStoreId;

  return [
    product.shopName,
    product.region,
    product.storeName,
    product.productUrl,
  ]
    .map((part) => cleanLower(part))
    .filter((part) => part.length > 0)
    .join("|");
}

function buildRegionKey(product) {
  const shopName = cleanString(product.shopName);
  const region = cleanString(product.region) || "All regions";

  return `${shopName}|${region}`;
}

function normalisePreferenceLookup(values) {
  return new Set(
    values
      .map((value) => cleanLower(value))
      .filter((value) => value.length > 0)
  );
}

function userPreferenceMatchesProduct(preferences, product) {
  if (!preferences || preferences.enabled === false) {
    return false;
  }

  const selectedShops = normalisePreferenceLookup(
    stringList(preferences.selectedShops)
  );
  const selectedRegions = normalisePreferenceLookup(
    stringList(preferences.selectedRegions)
  );
  const selectedStoreIds = normalisePreferenceLookup(
    stringList(preferences.selectedStoreIds)
  );

  const shopName = cleanLower(product.shopName);
  const regionKey = cleanLower(buildRegionKey(product));
  const storeId = cleanLower(buildStoreId(product));

  return (
    selectedShops.has(shopName) ||
    selectedRegions.has(regionKey) ||
    selectedStoreIds.has(storeId)
  );
}

function pageContainsAnyKeyword(pageText, keywords) {
  const lowerPageText = cleanLower(pageText);

  return keywords.some((keyword) => {
    const cleanKeyword = cleanLower(keyword);
    return cleanKeyword.length > 0 && lowerPageText.includes(cleanKeyword);
  });
}

function decideInStock(pageText, product) {
  const inStockKeywords = stringList(product.inStockKeywords);
  const outOfStockKeywords = stringList(product.outOfStockKeywords);

  const hasOutOfStockKeyword = pageContainsAnyKeyword(
    pageText,
    outOfStockKeywords
  );
  const hasInStockKeyword = pageContainsAnyKeyword(pageText, inStockKeywords);

  if (hasInStockKeyword && !hasOutOfStockKeyword) {
    return {
      inStock: true,
      status: "in_stock_keywords_found",
    };
  }

  if (hasOutOfStockKeyword && !hasInStockKeyword) {
    return {
      inStock: false,
      status: "out_of_stock_keywords_found",
    };
  }

  if (hasInStockKeyword && hasOutOfStockKeyword) {
    return {
      inStock: false,
      status: "mixed_keywords_found",
    };
  }

  return {
    inStock: false,
    status: "no_keywords_found",
  };
}

async function fetchProductPage(productUrl) {
  const url = normaliseUrl(productUrl);

  if (!url) {
    throw new ProductCheckError(
      "Missing product URL.",
      "missing_product_url",
      0
    );
  }

  const attempts = [
    {
      name: "desktop_browser_headers",
      headers: buildBrowserHeaders(url, false),
    },
    {
      name: "mobile_browser_headers",
      headers: buildBrowserHeaders(url, true),
    },
  ];

  let lastError = null;

  for (const attempt of attempts) {
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      DEFAULT_CHECK_TIMEOUT_MS
    );

    try {
      const response = await fetch(url, {
        method: "GET",
        redirect: "follow",
        signal: controller.signal,
        headers: attempt.headers,
      });

      const pageText = await response.text();

      if (response.ok) {
        return pageText;
      }

      const checkStatus = httpCheckStatus(response.status);
      const message = httpStatusMessage(response.status, response.statusText);

      lastError = new ProductCheckError(
        message,
        checkStatus,
        response.status
      );

      logger.warn("Product page returned non-OK HTTP status.", {
        productUrl: url,
        attempt: attempt.name,
        httpStatus: response.status,
        checkStatus,
        message,
      });

      if (response.status === 403 || response.status === 429) {
        continue;
      }

      throw lastError;
    } catch (error) {
      if (error && error.name === "AbortError") {
        throw new ProductCheckError("Check timed out", "check_timed_out", 0);
      }

      if (error instanceof ProductCheckError) {
        lastError = error;

        if (error.httpStatus === 403 || error.httpStatus === 429) {
          continue;
        }

        throw error;
      }

      throw new ProductCheckError(
        `Check failed: ${productCheckMessageFromError(error)}`,
        "check_failed",
        0
      );
    } finally {
      clearTimeout(timeout);
    }
  }

  if (lastError) {
    throw lastError;
  }

  throw new ProductCheckError("Check failed", "check_failed", 0);
}

async function readTokensForUser(userId, tokenRefsByToken) {
  const tokensSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("fcmTokens")
    .get();

  tokensSnapshot.docs.forEach((tokenDoc) => {
    const token = cleanString(tokenDoc.data().token);

    if (token) {
      tokenRefsByToken.set(token, tokenDoc.ref);
    }
  });
}

async function getTokensForUser(userId) {
  const tokenRefsByToken = new Map();

  await readTokensForUser(userId, tokenRefsByToken);

  return {
    tokens: Array.from(tokenRefsByToken.keys()),
    tokenRefsByToken,
  };
}

function truncateForNotification(value, maxLength) {
  const text = cleanString(value).replace(/\s+/g, " ");

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.substring(0, Math.max(0, maxLength - 1)).trim()}…`;
}

function cleanNotificationData(data) {
  const cleanedData = {};

  Object.entries(data || {}).forEach(([key, value]) => {
    cleanedData[key] = cleanString(value);
  });

  return cleanedData;
}

function isInvalidFcmTokenError(errorCode) {
  return (
    errorCode === "messaging/registration-token-not-registered" ||
    errorCode === "messaging/invalid-registration-token"
  );
}

function isAlreadyExistsError(error) {
  return (
    error &&
    (error.code === 6 ||
      error.code === "already-exists" ||
      error.code === "ALREADY_EXISTS")
  );
}

function safeDedupeId(value) {
  return cleanString(value)
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .substring(0, 1400);
}

async function shouldSendNotificationOnce(dedupeId, metadata) {
  const cleanDedupeId = safeDedupeId(dedupeId);

  if (!cleanDedupeId) {
    return true;
  }

  const dedupeRef = db.collection("notification_dedup").doc(cleanDedupeId);

  try {
    await dedupeRef.create({
      ...cleanNotificationData(metadata),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return true;
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      logger.info("Skipping duplicate notification.", {
        dedupeId: cleanDedupeId,
      });
      return false;
    }

    throw error;
  }
}

async function getUserDisplayName(userId) {
  const cleanUserId = cleanString(userId);

  if (!cleanUserId) {
    return "Someone";
  }

  try {
    const userSnapshot = await db.collection("users").doc(cleanUserId).get();

    if (!userSnapshot.exists) {
      return "Someone";
    }

    const user = userSnapshot.data() || {};

    return (
      cleanString(user.username) ||
      cleanString(user.displayName) ||
      cleanString(user.name) ||
      cleanString(user.email) ||
      "Someone"
    );
  } catch (error) {
    logger.warn("Could not read user display name.", {
      userId: cleanUserId,
      error: productCheckMessageFromError(error),
    });
    return "Someone";
  }
}

async function sendPushToUser({ userId, title, body, data, logContext }) {
  const cleanUserId = cleanString(userId);

  if (!cleanUserId) {
    logger.warn("Cannot send notification without a userId.", logContext || {});
    return {
      successCount: 0,
      failureCount: 0,
      tokenCount: 0,
    };
  }

  const { tokens, tokenRefsByToken } = await getTokensForUser(cleanUserId);

  if (tokens.length === 0) {
    logger.info("No FCM tokens found for notification recipient.", {
      ...(logContext || {}),
      userId: cleanUserId,
    });

    return {
      successCount: 0,
      failureCount: 0,
      tokenCount: 0,
    };
  }

  let successCount = 0;
  let failureCount = 0;
  const invalidTokenDeletePromises = [];

  for (let index = 0; index < tokens.length; index += 500) {
    const tokenBatch = tokens.slice(index, index + 500);

    const response = await messaging.sendEachForMulticast({
      tokens: tokenBatch,
      notification: {
        title: truncateForNotification(title, 80),
        body: truncateForNotification(body, 180),
      },
      data: cleanNotificationData({
        ...(data || {}),
        recipientUid: cleanUserId,
      }),
      android: {
        priority: "high",
        notification: {
          channelId: NOTIFICATION_CHANNEL_ID,
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    successCount += response.successCount;
    failureCount += response.failureCount;

    response.responses.forEach((sendResponse, responseIndex) => {
      if (sendResponse.success) return;

      const token = tokenBatch[responseIndex];
      const errorCode = sendResponse.error && sendResponse.error.code;

      logger.warn("Failed to send user notification.", {
        ...(logContext || {}),
        userId: cleanUserId,
        errorCode,
      });

      if (isInvalidFcmTokenError(errorCode)) {
        const tokenRef = tokenRefsByToken.get(token);

        if (tokenRef) {
          invalidTokenDeletePromises.push(tokenRef.delete());
        }
      }
    });
  }

  await Promise.all(invalidTokenDeletePromises);

  logger.info("User notification sent.", {
    ...(logContext || {}),
    userId: cleanUserId,
    successCount,
    failureCount,
    tokenCount: tokens.length,
  });

  return {
    successCount,
    failureCount,
    tokenCount: tokens.length,
  };
}

async function sendNotificationToRecipientsOnce({
  recipients,
  dedupePrefix,
  title,
  body,
  data,
  logContext,
}) {
  const uniqueRecipients = Array.from(
    new Set(
      (recipients || [])
        .map((recipient) => cleanString(recipient))
        .filter(Boolean)
    )
  );

  const results = [];

  for (const recipientUid of uniqueRecipients) {
    const dedupeId = `${dedupePrefix}:${recipientUid}`;
    const shouldSend = await shouldSendNotificationOnce(dedupeId, {
      ...(logContext || {}),
      recipientUid,
      type: data && data.type,
    });

    if (!shouldSend) {
      continue;
    }

    const result = await sendPushToUser({
      userId: recipientUid,
      title,
      body,
      data: {
        ...(data || {}),
        recipientUid,
      },
      logContext: {
        ...(logContext || {}),
        recipientUid,
      },
    });

    results.push({
      recipientUid,
      ...result,
    });
  }

  return results;
}

function totalsFromNotificationResults(results) {
  return (results || []).reduce(
    (totals, result) => ({
      successCount: totals.successCount + (result.successCount || 0),
      failureCount: totals.failureCount + (result.failureCount || 0),
      tokenCount: totals.tokenCount + (result.tokenCount || 0),
      recipientCount: totals.recipientCount + 1,
    }),
    {
      successCount: 0,
      failureCount: 0,
      tokenCount: 0,
      recipientCount: 0,
    }
  );
}

function otherParticipants(participants, senderId) {
  const cleanSenderId = cleanString(senderId);

  if (!Array.isArray(participants)) {
    return [];
  }

  return participants
    .map((participant) => cleanString(participant))
    .filter(
      (participant) =>
        participant.length > 0 && participant !== cleanSenderId
    );
}

async function getMatchingUserTokens(product) {
  const enabledUsersSnapshot = await db
    .collection("user_feature_flags")
    .where("restockAlertsEnabled", "==", true)
    .get();

  if (enabledUsersSnapshot.empty) {
    return {
      tokens: [],
      tokenRefsByToken: new Map(),
      matchedUserCount: 0,
    };
  }

  const preferenceReadPromises = enabledUsersSnapshot.docs.map(async (flagDoc) => {
    const userId = flagDoc.id;

    const preferenceDoc = await db
      .collection("user_restock_alert_preferences")
      .doc(userId)
      .get();

    const preferences = preferenceDoc.exists ? preferenceDoc.data() : null;

    if (!userPreferenceMatchesProduct(preferences, product)) {
      return null;
    }

    return userId;
  });

  const matchedUserIds = (await Promise.all(preferenceReadPromises)).filter(
    Boolean
  );

  const tokenRefsByToken = new Map();

  await Promise.all(
    matchedUserIds.map((userId) => readTokensForUser(userId, tokenRefsByToken))
  );

  return {
    tokens: Array.from(tokenRefsByToken.keys()),
    tokenRefsByToken,
    matchedUserCount: matchedUserIds.length,
  };
}

async function sendRestockNotificationsForProduct(productId, product) {
  const { tokens, tokenRefsByToken, matchedUserCount } =
    await getMatchingUserTokens(product);

  if (tokens.length === 0) {
    logger.info("No matching user tokens found for restock.", {
      productId,
      shopName: product.shopName,
      region: product.region,
      storeName: product.storeName,
      matchedUserCount,
    });

    return {
      successCount: 0,
      failureCount: 0,
      tokenCount: 0,
      matchedUserCount,
    };
  }

  const shopName = cleanString(product.shopName);
  const productName = cleanString(product.productName);
  const region = cleanString(product.region);
  const storeName = cleanString(product.storeName);
  const productUrl = cleanString(product.productUrl);

  const locationParts = [shopName, region, storeName].filter(
    (part) => cleanString(part).length > 0
  );
  const body = locationParts.join(" • ");

  let successCount = 0;
  let failureCount = 0;
  const invalidTokenDeletePromises = [];

  for (let index = 0; index < tokens.length; index += 500) {
    const tokenBatch = tokens.slice(index, index + 500);

    const response = await messaging.sendEachForMulticast({
      tokens: tokenBatch,
      notification: {
        title: `${productName} is back in stock`,
        body,
      },
      data: {
        type: "tracked_restock",
        productId,
        shopName,
        productName,
        productUrl,
        region,
        storeName,
      },
      android: {
        priority: "high",
        notification: {
          channelId: NOTIFICATION_CHANNEL_ID,
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    successCount += response.successCount;
    failureCount += response.failureCount;

    response.responses.forEach((sendResponse, responseIndex) => {
      if (sendResponse.success) return;

      const token = tokenBatch[responseIndex];
      const errorCode = sendResponse.error && sendResponse.error.code;

      logger.warn("Failed to send tracked restock notification.", {
        productId,
        errorCode,
      });

      if (
        errorCode === "messaging/registration-token-not-registered" ||
        errorCode === "messaging/invalid-registration-token"
      ) {
        const tokenRef = tokenRefsByToken.get(token);

        if (tokenRef) {
          invalidTokenDeletePromises.push(tokenRef.delete());
        }
      }
    });
  }

  await Promise.all(invalidTokenDeletePromises);

  logger.info("Tracked restock notifications sent.", {
    productId,
    successCount,
    failureCount,
    tokenCount: tokens.length,
    matchedUserCount,
  });

  return {
    successCount,
    failureCount,
    tokenCount: tokens.length,
    matchedUserCount,
  };
}

async function sendRestockNotificationToOwner(userId, productId, product) {
  const { tokens, tokenRefsByToken } = await getTokensForUser(userId);

  if (tokens.length === 0) {
    logger.info("No FCM tokens found for user tracked product.", {
      userId,
      productId,
    });

    return {
      successCount: 0,
      failureCount: 0,
      tokenCount: 0,
    };
  }

  const shopName = cleanString(product.shopName);
  const productName = cleanString(product.productName);
  const region = cleanString(product.region);
  const storeName = cleanString(product.storeName);
  const productUrl = cleanString(product.productUrl);

  const locationParts = [shopName, region, storeName].filter(
    (part) => cleanString(part).length > 0
  );
  const body = locationParts.join(" • ");

  let successCount = 0;
  let failureCount = 0;
  const invalidTokenDeletePromises = [];

  for (let index = 0; index < tokens.length; index += 500) {
    const tokenBatch = tokens.slice(index, index + 500);

    const response = await messaging.sendEachForMulticast({
      tokens: tokenBatch,
      notification: {
        title: `${productName} is back in stock`,
        body,
      },
      data: {
        type: "user_tracked_restock",
        productId,
        shopName,
        productName,
        productUrl,
        region,
        storeName,
      },
      android: {
        priority: "high",
        notification: {
          channelId: NOTIFICATION_CHANNEL_ID,
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    successCount += response.successCount;
    failureCount += response.failureCount;

    response.responses.forEach((sendResponse, responseIndex) => {
      if (sendResponse.success) return;

      const token = tokenBatch[responseIndex];
      const errorCode = sendResponse.error && sendResponse.error.code;

      logger.warn("Failed to send user tracked restock notification.", {
        userId,
        productId,
        errorCode,
      });

      if (
        errorCode === "messaging/registration-token-not-registered" ||
        errorCode === "messaging/invalid-registration-token"
      ) {
        const tokenRef = tokenRefsByToken.get(token);

        if (tokenRef) {
          invalidTokenDeletePromises.push(tokenRef.delete());
        }
      }
    });
  }

  await Promise.all(invalidTokenDeletePromises);

  return {
    successCount,
    failureCount,
    tokenCount: tokens.length,
  };
}

async function checkOneTrackedProduct({
  productRef,
  productId,
  product,
  notifyWhenBackInStock,
}) {
  const productUrl = cleanString(product.productUrl);

  if (!productUrl) {
    await productRef.set(
      {
        lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastCheckStatus: "missing_product_url",
        lastCheckError: "Missing product URL.",
      },
      { merge: true }
    );
    return;
  }

  try {
    const pageText = await fetchProductPage(productUrl);
    const stockDecision = decideInStock(pageText, product);
    const wasInStock = product.inStock === true;
    const nowInStock = stockDecision.inStock === true;

    let notificationResult = null;

    if (!wasInStock && nowInStock) {
      notificationResult = await notifyWhenBackInStock();
    }

    await productRef.set(
      {
        inStock: nowInStock,
        lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastCheckStatus: stockDecision.status,
        lastCheckError: "",
        ...(notificationResult
          ? {
              lastAlertedAt: admin.firestore.FieldValue.serverTimestamp(),
              lastNotificationSuccessCount: notificationResult.successCount,
              lastNotificationFailureCount: notificationResult.failureCount,
              lastNotificationTokenCount: notificationResult.tokenCount,
              ...(notificationResult.matchedUserCount !== undefined
                ? {
                    lastNotificationMatchedUserCount:
                      notificationResult.matchedUserCount,
                  }
                : {}),
            }
          : {}),
      },
      { merge: true }
    );

    logger.info("Tracked product checked.", {
      productId,
      productName: product.productName,
      shopName: product.shopName,
      region: product.region,
      storeName: product.storeName,
      wasInStock,
      nowInStock,
      status: stockDecision.status,
    });
  } catch (error) {
    await productRef.set(
      {
        lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastCheckStatus: productCheckStatusFromError(error),
        lastCheckError: productCheckMessageFromError(error),
      },
      { merge: true }
    );

    logger.error("Failed to check tracked product.", {
      productId,
      productUrl,
      error: productCheckMessageFromError(error),
    });
  }
}

exports.checkTrackedRestocks = onSchedule(
  {
    schedule: "every 30 minutes",
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    const productsSnapshot = await db
      .collection("tracked_restock_products")
      .where("enabled", "==", true)
      .get();

    if (productsSnapshot.empty) {
      logger.info("No tracked products enabled.");
      return;
    }

    logger.info("Checking tracked restock products.", {
      count: productsSnapshot.size,
    });

    for (const productDoc of productsSnapshot.docs) {
      const productId = productDoc.id;
      const product = productDoc.data();

      const productUrl = cleanString(product.productUrl);

      if (!productUrl) {
        await productDoc.ref.set(
          {
            lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastCheckStatus: "missing_product_url",
            lastCheckError: "Missing product URL.",
          },
          { merge: true }
        );
        continue;
      }

      try {
        const pageText = await fetchProductPage(productUrl);
        const stockDecision = decideInStock(pageText, product);
        const wasInStock = product.inStock === true;
        const nowInStock = stockDecision.inStock === true;

        let notificationResult = null;

        if (!wasInStock && nowInStock) {
          notificationResult = await sendRestockNotificationsForProduct(
            productId,
            product
          );
        }

        await productDoc.ref.set(
          {
            inStock: nowInStock,
            lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastCheckStatus: stockDecision.status,
            lastCheckError: "",
            ...(notificationResult
              ? {
                  lastAlertedAt: admin.firestore.FieldValue.serverTimestamp(),
                  lastNotificationSuccessCount:
                    notificationResult.successCount,
                  lastNotificationFailureCount:
                    notificationResult.failureCount,
                  lastNotificationTokenCount: notificationResult.tokenCount,
                  lastNotificationMatchedUserCount:
                    notificationResult.matchedUserCount,
                }
              : {}),
          },
          { merge: true }
        );

        logger.info("Tracked product checked.", {
          productId,
          productName: product.productName,
          shopName: product.shopName,
          region: product.region,
          storeName: product.storeName,
          wasInStock,
          nowInStock,
          status: stockDecision.status,
        });
      } catch (error) {
        await productDoc.ref.set(
          {
            lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastCheckStatus: productCheckStatusFromError(error),
            lastCheckError: productCheckMessageFromError(error),
          },
          { merge: true }
        );

        logger.error("Failed to check tracked product.", {
          productId,
          productUrl,
          error: productCheckMessageFromError(error),
        });
      }
    }
  }
);

exports.checkUserTrackedRestocks = onSchedule(
  {
    schedule: "every 30 minutes",
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    const enabledProductsSnapshot = await db
      .collectionGroup("tracked_restock_products")
      .where("enabled", "==", true)
      .get();

    const userProductDocs = enabledProductsSnapshot.docs.filter((doc) => {
      const path = doc.ref.path;
      return path.startsWith("users/") && path.includes("/tracked_restock_products/");
    });

    if (userProductDocs.length === 0) {
      logger.info("No user tracked products enabled.");
      return;
    }

    logger.info("Checking user tracked restock products.", {
      count: userProductDocs.length,
    });

    for (const productDoc of userProductDocs) {
      const productId = productDoc.id;
      const product = productDoc.data();
      const userId = cleanString(product.userId) || productDoc.ref.parent.parent.id;

      await checkOneTrackedProduct({
        productRef: productDoc.ref,
        productId,
        product,
        notifyWhenBackInStock: () =>
          sendRestockNotificationToOwner(userId, productId, product),
      });
    }
  }
);

exports.sendRestockAlertNotifications = onDocumentCreated(
  {
    document: "restock_alerts/{alertId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn("No restock alert snapshot found.");
      return;
    }

    const alertId = event.params.alertId;
    const alert = snapshot.data();

    if (alert.inStock !== true) {
      logger.info("Restock alert is not marked as in stock. Skipping.", {
        alertId,
      });
      return;
    }

    const product = {
      shopName: cleanString(alert.shopName),
      productName: cleanString(alert.productName),
      productUrl: cleanString(alert.productUrl),
      region: cleanString(alert.region),
      storeName: cleanString(alert.storeName),
      storeId: cleanString(alert.storeId),
    };

    if (!product.shopName || !product.productName) {
      logger.warn("Restock alert is missing shopName or productName.", {
        alertId,
      });
      return;
    }

    const result = await sendRestockNotificationsForProduct(alertId, product);

    await snapshot.ref.set(
      {
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationSuccessCount: result.successCount,
        notificationFailureCount: result.failureCount,
        notificationTokenCount: result.tokenCount,
        notificationMatchedUserCount: result.matchedUserCount,
      },
      { merge: true }
    );
  }
);

exports.sendFriendRequestNotification = onDocumentCreated(
  {
    document: "friend_requests/{requestId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn("No friend request snapshot found.");
      return;
    }

    const requestId = event.params.requestId;
    const friendRequest = snapshot.data() || {};
    const toUid = cleanString(friendRequest.toUid);
    const fromUid = cleanString(friendRequest.fromUid);
    const status = cleanString(friendRequest.status);

    if (!toUid || !fromUid || toUid === fromUid) {
      logger.warn("Friend request is missing sender or recipient.", {
        requestId,
        toUid,
        fromUid,
      });
      return;
    }

    if (status && status !== "pending") {
      logger.info("Friend request is not pending. Skipping notification.", {
        requestId,
        status,
      });
      return;
    }

    const fromName =
      cleanString(friendRequest.fromName) || (await getUserDisplayName(fromUid));

    const shouldSend = await shouldSendNotificationOnce(
      `friend_request:${requestId}:${toUid}`,
      {
        type: "friend_request",
        requestId,
        fromUid,
        toUid,
      }
    );

    if (!shouldSend) return;

    const result = await sendPushToUser({
      userId: toUid,
      title: "New friend request",
      body: `${fromName} sent you a friend request`,
      data: {
        type: "friend_request",
        requestId,
        fromUid,
        fromName,
        toUid,
      },
      logContext: {
        type: "friend_request",
        requestId,
        fromUid,
        toUid,
      },
    });

    await snapshot.ref.set(
      {
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationSuccessCount: result.successCount,
        notificationFailureCount: result.failureCount,
        notificationTokenCount: result.tokenCount,
      },
      { merge: true }
    );
  }
);

exports.sendChatMessageNotification = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn("No chat message snapshot found.");
      return;
    }

    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const message = snapshot.data() || {};
    const senderId = cleanString(message.senderId);
    const text = cleanString(message.text);

    if (!senderId) {
      logger.warn("Chat message is missing senderId.", {
        chatId,
        messageId,
      });
      return;
    }

    const chatSnapshot = await db.collection("chats").doc(chatId).get();

    if (!chatSnapshot.exists) {
      logger.warn("Chat document does not exist for message notification.", {
        chatId,
        messageId,
      });
      return;
    }

    const chat = chatSnapshot.data() || {};
    const recipients = otherParticipants(chat.participants, senderId);

    if (recipients.length === 0) {
      logger.info("No recipients found for chat message notification.", {
        chatId,
        messageId,
        senderId,
      });
      return;
    }

    const senderName = await getUserDisplayName(senderId);
    const body = text
      ? `${senderName}: ${text}`
      : `${senderName} sent you a message`;

    const results = await sendNotificationToRecipientsOnce({
      recipients,
      dedupePrefix: `chat_message:${chatId}:${messageId}`,
      title: "New message",
      body,
      data: {
        type: "chat_message",
        chatId,
        messageId,
        senderId,
        senderName,
      },
      logContext: {
        type: "chat_message",
        chatId,
        messageId,
        senderId,
      },
    });

    const totals = totalsFromNotificationResults(results);

    await snapshot.ref.set(
      {
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationSuccessCount: totals.successCount,
        notificationFailureCount: totals.failureCount,
        notificationTokenCount: totals.tokenCount,
        notificationRecipientCount: totals.recipientCount,
      },
      { merge: true }
    );
  }
);

exports.sendCommunityPrivateMessageNotification = onDocumentCreated(
  {
    document: "community_private_conversations/{conversationId}/messages/{messageId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn("No private message snapshot found.");
      return;
    }

    const conversationId = event.params.conversationId;
    const messageId = event.params.messageId;
    const message = snapshot.data() || {};
    const senderId = cleanString(message.authorId);
    const senderName =
      cleanString(message.authorName) || (await getUserDisplayName(senderId));
    const messageText = cleanString(message.message);

    if (!senderId) {
      logger.warn("Private message is missing authorId.", {
        conversationId,
        messageId,
      });
      return;
    }

    const conversationSnapshot = await db
      .collection("community_private_conversations")
      .doc(conversationId)
      .get();

    if (!conversationSnapshot.exists) {
      logger.warn("Private conversation document does not exist.", {
        conversationId,
        messageId,
      });
      return;
    }

    const conversation = conversationSnapshot.data() || {};
    const recipients = otherParticipants(conversation.participants, senderId);

    if (recipients.length === 0) {
      logger.info("No recipients found for private message notification.", {
        conversationId,
        messageId,
        senderId,
      });
      return;
    }

    const body = messageText
      ? `${senderName}: ${messageText}`
      : `${senderName} sent you a private message`;

    const results = await sendNotificationToRecipientsOnce({
      recipients,
      dedupePrefix: `private_message:${conversationId}:${messageId}`,
      title: "New private message",
      body,
      data: {
        type: "private_message",
        conversationId,
        messageId,
        senderId,
        senderName,
      },
      logContext: {
        type: "private_message",
        conversationId,
        messageId,
        senderId,
      },
    });

    const totals = totalsFromNotificationResults(results);

    await snapshot.ref.set(
      {
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationSuccessCount: totals.successCount,
        notificationFailureCount: totals.failureCount,
        notificationTokenCount: totals.tokenCount,
        notificationRecipientCount: totals.recipientCount,
      },
      { merge: true }
    );
  }
);

exports.sendMirroredCommunityPrivateMessageNotification = onDocumentCreated(
  {
    document:
      "users/{userId}/community_private_conversations/{conversationId}/messages/{messageId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn("No mirrored private message snapshot found.");
      return;
    }

    const recipientUid = cleanString(event.params.userId);
    const conversationId = event.params.conversationId;
    const messageId = event.params.messageId;
    const message = snapshot.data() || {};
    const senderId = cleanString(message.authorId);
    const senderName =
      cleanString(message.authorName) || (await getUserDisplayName(senderId));
    const messageText = cleanString(message.message);

    if (!recipientUid || !senderId || recipientUid === senderId) {
      logger.info("Skipping mirrored private message notification.", {
        recipientUid,
        senderId,
        conversationId,
        messageId,
      });
      return;
    }

    const shouldSend = await shouldSendNotificationOnce(
      `private_message:${conversationId}:${messageId}:${recipientUid}`,
      {
        type: "private_message",
        conversationId,
        messageId,
        senderId,
        recipientUid,
      }
    );

    if (!shouldSend) return;

    const body = messageText
      ? `${senderName}: ${messageText}`
      : `${senderName} sent you a private message`;

    const result = await sendPushToUser({
      userId: recipientUid,
      title: "New private message",
      body,
      data: {
        type: "private_message",
        conversationId,
        messageId,
        senderId,
        senderName,
        recipientUid,
      },
      logContext: {
        type: "private_message_mirror",
        conversationId,
        messageId,
        senderId,
        recipientUid,
      },
    });

    await snapshot.ref.set(
      {
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationSuccessCount: result.successCount,
        notificationFailureCount: result.failureCount,
        notificationTokenCount: result.tokenCount,
      },
      { merge: true }
    );
  }
);

async function getAppRole(userId) {
  const cleanUserId = cleanString(userId);

  if (!cleanUserId) {
    return "";
  }

  const roleSnapshot = await db.collection("app_roles").doc(cleanUserId).get();

  if (!roleSnapshot.exists) {
    return "";
  }

  return cleanLower(roleSnapshot.data().role);
}

async function isAdminOrModeratorUser(userId) {
  const role = await getAppRole(userId);
  return role === "admin" || role === "moderator";
}

async function userHasProAccess(userId) {
  const cleanUserId = cleanString(userId);

  if (!cleanUserId) {
    return false;
  }

  const flagSnapshot = await db
    .collection("user_feature_flags")
    .doc(cleanUserId)
    .get();

  // Some Pro purchases in the app are stored locally after purchase restore.
  // If there is no server-side flag document, the app-side ProStatusService
  // controls whether this callable can be reached from the UI.
  if (!flagSnapshot.exists) {
    return true;
  }

  return flagSnapshot.data().proEnabled === true;
}

function readCallableAuthUid(request) {
  const uid = cleanString(request.auth && request.auth.uid);

  if (!uid) {
    throw new HttpsError("unauthenticated", "Please sign in first.");
  }

  return uid;
}

function readCallablePostId(request) {
  const postId = cleanString(request.data && request.data.postId);

  if (!postId) {
    throw new HttpsError("invalid-argument", "Missing post id.");
  }

  return postId;
}

exports.setUserFeaturedCommunityPost = onCall(
  {
    region: REGION,
  },
  async (request) => {
    const uid = readCallableAuthUid(request);
    const postId = readCallablePostId(request);
    const shouldFeature = request.data && request.data.featured !== false;

    const hasProAccess = await userHasProAccess(uid);

    if (!hasProAccess) {
      throw new HttpsError(
        "permission-denied",
        "PocketChase Pro is required to choose a featured post."
      );
    }

    const postRef = db.collection("community_posts").doc(postId);
    const selectedRef = db
      .collection("users")
      .doc(uid)
      .collection("community_featured_posts")
      .doc("current");

    await db.runTransaction(async (transaction) => {
      const postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) {
        throw new HttpsError("not-found", "Post not found.");
      }

      const post = postSnapshot.data() || {};
      const authorId = cleanString(post.authorId);

      if (authorId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "You can only feature one of your own posts."
        );
      }

      const selectedSnapshot = await transaction.get(selectedRef);
      const previousPostId = selectedSnapshot.exists
        ? cleanString(selectedSnapshot.data().postId)
        : "";
      const nowMs = Date.now();

      if (previousPostId && previousPostId !== postId) {
        const previousPostRef = db.collection("community_posts").doc(previousPostId);
        transaction.set(
          previousPostRef,
          {
            featuredByUser: false,
            featuredByUserId: "",
            featuredByUserAtMs: 0,
            updatedAtMs: nowMs,
          },
          { merge: true }
        );
      }

      if (shouldFeature) {
        transaction.set(
          postRef,
          {
            featuredByUser: true,
            featuredByUserId: uid,
            featuredByUserAtMs: nowMs,
            updatedAtMs: nowMs,
          },
          { merge: true }
        );
        transaction.set(
          selectedRef,
          {
            postId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAtMs: nowMs,
          },
          { merge: true }
        );
      } else {
        transaction.set(
          postRef,
          {
            featuredByUser: false,
            featuredByUserId: "",
            featuredByUserAtMs: 0,
            updatedAtMs: nowMs,
          },
          { merge: true }
        );

        if (previousPostId === postId) {
          transaction.delete(selectedRef);
        }
      }
    });

    logger.info("User featured community post updated.", {
      uid,
      postId,
      featured: shouldFeature,
    });

    return {
      ok: true,
      postId,
      featured: shouldFeature,
    };
  }
);

exports.setAdminFeaturedCommunityPost = onCall(
  {
    region: REGION,
  },
  async (request) => {
    const uid = readCallableAuthUid(request);
    const postId = readCallablePostId(request);
    const shouldFeature = request.data && request.data.featured !== false;

    const canAdminFeature = await isAdminOrModeratorUser(uid);

    if (!canAdminFeature) {
      throw new HttpsError(
        "permission-denied",
        "Only admins or moderators can admin-feature posts."
      );
    }

    const postRef = db.collection("community_posts").doc(postId);
    const nowMs = Date.now();

    await db.runTransaction(async (transaction) => {
      const postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) {
        throw new HttpsError("not-found", "Post not found.");
      }

      transaction.set(
        postRef,
        shouldFeature
          ? {
              featuredByAdmin: true,
              featuredByAdminUid: uid,
              featuredByAdminAtMs: nowMs,
              updatedAtMs: nowMs,
            }
          : {
              featuredByAdmin: false,
              featuredByAdminUid: "",
              featuredByAdminAtMs: 0,
              updatedAtMs: nowMs,
            },
        { merge: true }
      );
    });

    logger.info("Admin featured community post updated.", {
      uid,
      postId,
      featured: shouldFeature,
    });

    return {
      ok: true,
      postId,
      featured: shouldFeature,
    };
  }
);


exports.adminDeleteUser = onCall(
  {
    region: REGION,
  },
  async (request) => {
    const callerUid = readCallableAuthUid(request);
    const targetUid = cleanString(request.data && request.data.uid);

    if (!targetUid) {
      throw new HttpsError("invalid-argument", "Missing user UID.");
    }

    if (targetUid === callerUid) {
      throw new HttpsError(
        "failed-precondition",
        "You cannot delete your own admin account."
      );
    }

    const callerRole = await getAppRole(callerUid);

    if (callerRole !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only admins can delete users."
      );
    }

    const targetUserSnapshot = await db.collection("users").doc(targetUid).get();
    const targetUser = targetUserSnapshot.exists
      ? targetUserSnapshot.data() || {}
      : {};

    const deletedUserAuditRef = db
      .collection("admin_deleted_users")
      .doc(targetUid);

    await deletedUserAuditRef.set(
      {
        uid: targetUid,
        email: cleanString(targetUser.email),
        username:
          cleanString(targetUser.username) ||
          cleanString(targetUser.displayName) ||
          cleanString(targetUser.businessName),
        accountType: cleanString(targetUser.accountType),
        deletedBy: callerUid,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const deletePromises = [
      db.recursiveDelete(db.collection("users").doc(targetUid)).catch((error) => {
        logger.warn("Could not recursive-delete user Firestore document.", {
          targetUid,
          error: productCheckMessageFromError(error),
        });
      }),
      db.collection("user_feature_flags").doc(targetUid).delete().catch(() => null),
      db.collection("app_roles").doc(targetUid).delete().catch(() => null),
      db
        .collection("user_restock_alert_preferences")
        .doc(targetUid)
        .delete()
        .catch(() => null),
    ];

    const friendRequestsSnapshot = await db
      .collection("friend_requests")
      .where("participants", "array-contains", targetUid)
      .get()
      .catch(() => null);

    if (friendRequestsSnapshot) {
      friendRequestsSnapshot.docs.forEach((doc) => {
        deletePromises.push(doc.ref.delete().catch(() => null));
      });
    }

    const communityPostsSnapshot = await db
      .collection("community_posts")
      .where("authorId", "==", targetUid)
      .get()
      .catch(() => null);

    if (communityPostsSnapshot) {
      communityPostsSnapshot.docs.forEach((doc) => {
        deletePromises.push(doc.ref.delete().catch(() => null));
      });
    }

    const shopSubmissionsSnapshot = await db
      .collection("tcg_shop_submissions")
      .where("submittedBy", "==", targetUid)
      .get()
      .catch(() => null);

    if (shopSubmissionsSnapshot) {
      shopSubmissionsSnapshot.docs.forEach((doc) => {
        deletePromises.push(doc.ref.delete().catch(() => null));
      });
    }

    await Promise.all(deletePromises);

    try {
      await admin.auth().deleteUser(targetUid);
    } catch (error) {
      if (error && error.code !== "auth/user-not-found") {
        throw new HttpsError(
          "internal",
          `Could not delete Firebase Auth user: ${productCheckMessageFromError(error)}`
        );
      }
    }

    logger.info("Admin deleted user.", {
      callerUid,
      targetUid,
    });

    return {
      ok: true,
      uid: targetUid,
    };
  }
);



exports.lookupExternalPokemonCardPrice =
  require("./lookup_external_pokemon_card_price").lookupExternalPokemonCardPrice;

exports.lookupEbaySealedProducts =
  require('./lookup_ebay_sealed_products').lookupEbaySealedProducts;

// UK sealed sold-price valuations use CompsAPI; active eBay search remains unchanged.
exports.lookupCompsSealedSoldPrices =
  require('./lookup_comps_sealed_sold_prices').lookupCompsSealedSoldPrices;

exports.adminApproveTcgShopSubmission =
  require("./admin_tcg_shop_submissions").adminApproveTcgShopSubmission;

exports.adminRejectTcgShopSubmission =
  require("./admin_tcg_shop_submissions").adminRejectTcgShopSubmission;

// Japanese catalogue artwork is supplied by PokéWallet. The API key remains
// in Firebase Secret Manager and is never included in the Flutter application.
let japaneseSetCache = null;
let japaneseSetCacheTime = 0;

function normaliseJapaneseLookup(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, "");
}

async function sendPushToAllUsersExcept({
  excludedUserId,
  title,
  body,
  data,
  logContext,
}) {
  const cleanExcludedUserId = cleanString(excludedUserId);
  const tokenSnapshot = await db.collectionGroup("fcmTokens").get();
  const tokenRefsByToken = new Map();

  tokenSnapshot.docs.forEach((tokenDoc) => {
    const ownerUserId = tokenDoc.ref.parent.parent
      ? cleanString(tokenDoc.ref.parent.parent.id)
      : "";
    const token = cleanString(tokenDoc.data().token);

    if (!token || ownerUserId === cleanExcludedUserId) return;
    tokenRefsByToken.set(token, tokenDoc.ref);
  });

  const tokens = Array.from(tokenRefsByToken.keys());
  if (tokens.length === 0) {
    logger.info("No FCM tokens found for community broadcast.", logContext || {});
    return { successCount: 0, failureCount: 0, tokenCount: 0 };
  }

  let successCount = 0;
  let failureCount = 0;
  const invalidTokenDeletePromises = [];

  for (let index = 0; index < tokens.length; index += 500) {
    const tokenBatch = tokens.slice(index, index + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: tokenBatch,
      notification: {
        title: truncateForNotification(title, 80),
        body: truncateForNotification(body, 180),
      },
      data: cleanNotificationData(data || {}),
      android: {
        priority: "high",
        notification: {
          channelId: NOTIFICATION_CHANNEL_ID,
          sound: "default",
        },
      },
      apns: { payload: { aps: { sound: "default" } } },
    });

    successCount += response.successCount;
    failureCount += response.failureCount;

    response.responses.forEach((sendResponse, responseIndex) => {
      if (sendResponse.success) return;
      const token = tokenBatch[responseIndex];
      const errorCode = sendResponse.error && sendResponse.error.code;
      if (isInvalidFcmTokenError(errorCode)) {
        const tokenRef = tokenRefsByToken.get(token);
        if (tokenRef) invalidTokenDeletePromises.push(tokenRef.delete());
      }
    });
  }

  await Promise.all(invalidTokenDeletePromises);
  logger.info("Community broadcast notification sent.", {
    ...(logContext || {}),
    successCount,
    failureCount,
    tokenCount: tokens.length,
  });

  return { successCount, failureCount, tokenCount: tokens.length };
}

function cardNumberKey(value) {
  const first = String(value || "").trim().split("/")[0];
  const numeric = first.match(/^0*(\d+)(.*)$/i);
  if (numeric) return `${Number(numeric[1])}${numeric[2].toLowerCase()}`;
  return normaliseJapaneseLookup(first);
}

async function pokewalletJson(path) {
  const response = await fetch(`https://api.pokewallet.io${path}`, {
    headers: { "X-API-Key": POKEWALLET_API_KEY.value() },
  });
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    logger.error("PokéWallet request failed.", {
      path,
      status: response.status,
      response: body.slice(0, 500),
    });
    throw new HttpsError(
      "unavailable",
      `Japanese artwork service returned HTTP ${response.status}.`
    );
  }
  return response.json();
}

async function japanesePokewalletSets() {
  const now = Date.now();
  if (japaneseSetCache && now - japaneseSetCacheTime < 6 * 60 * 60 * 1000) {
    return japaneseSetCache;
  }
  const payload = await pokewalletJson("/sets");
  japaneseSetCache = (Array.isArray(payload.data) ? payload.data : [])
    .filter((set) => {
      const language = String(set.language || "").toLowerCase();
      return ["jap", "ja", "jp", "japanese"].includes(language);
    });
  japaneseSetCacheTime = now;
  return japaneseSetCache;
}

function bestJapaneseSetMatch(sets, requested) {
  const wantedId = normaliseJapaneseLookup(requested.id);
  const wantedName = normaliseJapaneseLookup(requested.name);
  const wantedCount = Number(requested.cardCount || 0);
  const wantedDate = String(requested.releaseDate || "").slice(0, 10);
  const wantedYear = wantedDate.match(/\d{4}/)?.[0] || "";

  let best = null;
  let bestScore = 0;
  for (const set of sets) {
    const code = normaliseJapaneseLookup(set.set_code);
    const name = normaliseJapaneseLookup(set.name);
    const count = Number(set.card_count || 0);
    const releaseDate = String(set.release_date || "").slice(0, 10);
    const year = releaseDate.match(/\d{4}/)?.[0] || "";
    let score = 0;
    if (wantedId && code === wantedId) score += 120;
    else if (wantedId && code && (code.startsWith(wantedId) || wantedId.startsWith(code))) score += 65;
    if (wantedName && name === wantedName) score += 100;
    else if (wantedName && name && (name.includes(wantedName) || wantedName.includes(name))) score += 45;
    // An exact release date is the safest bridge between TCGdex's Japanese
    // catalogue IDs and PokéWallet's numeric set IDs. Card count alone must
    // never select a set (neo2 previously matched BW1 because both had 57).
    if (wantedDate && releaseDate === wantedDate) score += 120;
    else if (wantedYear && year === wantedYear) score += 10;
    if (wantedCount && count === wantedCount) score += 25;
    if (score > bestScore) {
      best = set;
      bestScore = score;
    }
  }
  return bestScore >= 60 ? best : null;
}

exports.lookupJapanesePokemonArtwork = onCall(
  { region: REGION, secrets: [POKEWALLET_API_KEY], timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in first.");
    const input = request.data || {};
    const suppliedCards = Array.isArray(input.cards) ? input.cards.slice(0, 300) : [];
    const sets = await japanesePokewalletSets();
    const matchedSet = bestJapaneseSetMatch(sets, input);
    if (!matchedSet) {
      logger.warn("No Japanese PokéWallet set match.", {
        requestedId: input.id,
        requestedName: input.name,
        requestedCardCount: input.cardCount,
        requestedReleaseDate: input.releaseDate,
        availableJapaneseSets: sets.length,
      });
      return { matched: false, cards: {} };
    }

    const setId = String(matchedSet.set_id || matchedSet.set_code || "");
    const remoteCards = [];
    for (let page = 1; page <= 5; page += 1) {
      const details = await pokewalletJson(
        `/sets/${encodeURIComponent(setId)}?page=${page}&limit=200`
      );
      const pageCards = Array.isArray(details.cards) ? details.cards : [];
      remoteCards.push(...pageCards);
      if (pageCards.length < 200) break;
    }
    const collectibleCards = remoteCards
      .filter((card) => String(card?.card_info?.product_type || "card") === "card");
    const byNumber = new Map();
    for (const remote of collectibleCards) {
      const key = cardNumberKey(remote?.card_info?.card_number);
      if (key && !byNumber.has(key)) byNumber.set(key, remote);
    }

    const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    const base = `https://${REGION}-${projectId}.cloudfunctions.net/pokewalletJapaneseImage`;
    const cards = {};
    const matchedRemoteIds = new Set();
    for (const supplied of suppliedCards) {
      const remote = byNumber.get(cardNumberKey(supplied.number));
      const sourceId = String(supplied.sourceId || "");
      const remoteId = String(remote?.id || "");
      if (sourceId && remoteId) {
        cards[sourceId] = `${base}?kind=card&id=${encodeURIComponent(remoteId)}`;
        matchedRemoteIds.add(remoteId);
      }
    }

    // Several early Japanese releases use PokéWallet numbering which differs
    // from TCGdex even though both lists are in printed set order. When the set
    // sizes agree, fill any unmatched entries by their catalogue position.
    // Existing exact-number matches are always retained.
    let positionalMatches = 0;
    if (collectibleCards.length === suppliedCards.length) {
      for (let index = 0; index < suppliedCards.length; index += 1) {
        const supplied = suppliedCards[index];
        const sourceId = String(supplied?.sourceId || "");
        if (!sourceId || cards[sourceId]) continue;
        const remoteId = String(collectibleCards[index]?.id || "");
        if (!remoteId || matchedRemoteIds.has(remoteId)) continue;
        cards[sourceId] = `${base}?kind=card&id=${encodeURIComponent(remoteId)}`;
        matchedRemoteIds.add(remoteId);
        positionalMatches += 1;
      }
    }
    logger.info("Matched Japanese PokéWallet artwork.", {
      requestedId: input.id,
      matchedSetId: setId,
      matchedSetCode: matchedSet.set_code,
      matchedSetName: matchedSet.name,
      suppliedCards: suppliedCards.length,
      remoteCards: collectibleCards.length,
      artworkMatches: Object.keys(cards).length,
      positionalMatches,
    });
    return {
      matched: true,
      setId,
      setImageUrl: `${base}?kind=set&id=${encodeURIComponent(setId)}`,
      cards,
    };
  }
);

async function getTcgShopReviewers() {
  const rolesSnapshot = await db.collection("app_roles").get();

  return rolesSnapshot.docs
    .filter((roleDoc) => {
      const role = cleanLower(roleDoc.data().role);
      return role === "admin" || role === "moderator";
    })
    .map((roleDoc) => roleDoc.id)
    .filter(Boolean);
}

async function notifyAdminsForReviewItem({
  snapshot,
  itemId,
  notificationType,
  title,
  body,
  route,
  extraData,
}) {
  if (!snapshot || !snapshot.exists) return;

  const reviewers = await getTcgShopReviewers();
  if (reviewers.length === 0) {
    logger.warn("No admin or moderator accounts found for review notification.", {
      notificationType,
      itemId,
    });
    return;
  }

  const results = await sendNotificationToRecipientsOnce({
    recipients: reviewers,
    dedupePrefix: `${notificationType}:${itemId}`,
    title,
    body,
    data: {
      type: notificationType,
      route,
      itemId,
      ...(extraData || {}),
    },
    logContext: { type: notificationType, itemId },
  });

  const totals = totalsFromNotificationResults(results);
  await snapshot.ref.set(
    {
      adminNotificationAttemptedAt:
        admin.firestore.FieldValue.serverTimestamp(),
      adminNotificationSuccessCount: totals.successCount,
      adminNotificationFailureCount: totals.failureCount,
      adminNotificationTokenCount: totals.tokenCount,
      adminNotificationRecipientCount: totals.recipientCount,
    },
    { merge: true }
  );
}

exports.sendNewMarketplacePostNotification = onDocumentCreated(
  {
    document: "community_posts/{postId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const postId = event.params.postId;
    const post = snapshot.data() || {};
    const postType = cleanString(post.postType);
    const marketplaceTypes = new Set(["For Sale", "Swap", "Wanted"]);

    if (!marketplaceTypes.has(postType) || post.hiddenFromUsers === true) return;

    const shouldSend = await shouldSendNotificationOnce(
      `community_marketplace_post:${postId}`,
      { type: "community_marketplace_post", postId, postType }
    );
    if (!shouldSend) return;

    const authorId = cleanString(post.authorId);
    const authorName = cleanString(post.authorName) || "A collector";
    const postTitle = cleanString(post.title) || "New marketplace post";
    const price = Number(post.askingPrice);
    const currency = cleanString(post.askingCurrency) || "GBP";
    const priceText =
      postType === "For Sale" && Number.isFinite(price) && price > 0
        ? ` • ${currency} ${price.toFixed(2)}`
        : "";

    const result = await sendPushToAllUsersExcept({
      excludedUserId: authorId,
      title: `New ${postType.toLowerCase()} post`,
      body: `${authorName}: ${postTitle}${priceText}`,
      data: {
        type: "community_marketplace_post",
        route: "community_post",
        postId,
        postType,
      },
      logContext: { type: "community_marketplace_post", postId, postType },
    });

    await snapshot.ref.set(
      {
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationSuccessCount: result.successCount,
        notificationFailureCount: result.failureCount,
        notificationTokenCount: result.tokenCount,
      },
      { merge: true }
    );
  }
);

exports.sendCommunityReplyNotification = onDocumentCreated(
  {
    document: "community_posts/{postId}/replies/{replyId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const postId = event.params.postId;
    const replyId = event.params.replyId;
    const reply = snapshot.data() || {};
    const replyAuthorId = cleanString(reply.authorId);
    const postSnapshot = await db.collection("community_posts").doc(postId).get();
    if (!postSnapshot.exists) return;

    const post = postSnapshot.data() || {};
    const postAuthorId = cleanString(post.authorId);
    if (!postAuthorId || postAuthorId === replyAuthorId) return;

    const replyAuthorName =
      cleanString(reply.authorName) || (await getUserDisplayName(replyAuthorId));
    const postTitle = cleanString(post.title) || "your community post";
    const message = cleanString(reply.message);
    const result = await sendPushToUser({
      userId: postAuthorId,
      title: "New reply to your post",
      body: message
        ? `${replyAuthorName}: ${message}`
        : `${replyAuthorName} replied to ${postTitle}`,
      data: {
        type: "community_post_reply",
        route: "community_post",
        postId,
        replyId,
      },
      logContext: { type: "community_post_reply", postId, replyId },
    });

    await snapshot.ref.set(
      {
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationSuccessCount: result.successCount,
        notificationFailureCount: result.failureCount,
        notificationTokenCount: result.tokenCount,
      },
      { merge: true }
    );
  }
);

exports.sendFeedbackReportAdminNotification = onDocumentCreated(
  { document: "feedback_reports/{reportId}", region: REGION },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const report = snapshot.data() || {};
    await notifyAdminsForReviewItem({
      snapshot,
      itemId: event.params.reportId,
      notificationType: "admin_feedback_report",
      title: "New feedback report",
      body: `${cleanString(report.type) || "Problem"}: ${cleanString(report.screen) || "PocketChase"}`,
      route: "admin_feedback_reports",
    });
  }
);

exports.sendCommunityReportAdminNotification = onDocumentCreated(
  { document: "community_reports/{reportId}", region: REGION },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const report = snapshot.data() || {};
    await notifyAdminsForReviewItem({
      snapshot,
      itemId: event.params.reportId,
      notificationType: "admin_community_report",
      title: "New community safety report",
      body: `${cleanString(report.reason) || "Report"}: ${cleanString(report.targetTitle) || cleanString(report.targetType) || "Community content"}`,
      route: "admin_community_reports",
    });
  }
);

exports.sendBusinessProRequestAdminNotification = onDocumentCreated(
  { document: "business_pro_requests/{requestId}", region: REGION },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const request = snapshot.data() || {};
    if (cleanLower(request.status || "pending") !== "pending") return;
    await notifyAdminsForReviewItem({
      snapshot,
      itemId: event.params.requestId,
      notificationType: "admin_business_pro_request",
      title: "New Business Pro request",
      body: `${cleanString(request.businessName) || cleanString(request.name) || "A business"} needs reviewing.`,
      route: "admin_business_requests",
    });
  }
);

exports.sendPendingBusinessProfileAdminNotification = onDocumentCreated(
  { document: "business_profiles/{businessId}", region: REGION },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const profile = snapshot.data() || {};
    if (cleanLower(profile.status || "pending") !== "pending") return;
    await notifyAdminsForReviewItem({
      snapshot,
      itemId: event.params.businessId,
      notificationType: "admin_business_profile",
      title: "New business profile",
      body: `${cleanString(profile.businessName) || "A business profile"} needs reviewing.`,
      route: "admin_business_profiles",
    });
  }
);

exports.sendArchivedPostAdminNotification = onDocumentUpdated(
  { document: "community_posts/{postId}", region: REGION },
  async (event) => {
    const before = event.data && event.data.before;
    const after = event.data && event.data.after;
    if (!before || !after) return;

    const beforeData = before.data() || {};
    const afterData = after.data() || {};
    if (beforeData.archivedForAdmin === true || afterData.archivedForAdmin !== true) {
      return;
    }

    await notifyAdminsForReviewItem({
      snapshot: after,
      itemId: event.params.postId,
      notificationType: "admin_archived_community_post",
      title: "Community post moved to archive",
      body: `${cleanString(afterData.title) || "A community post"} needs admin review.`,
      route: "admin_community_archive",
    });
  }
);

async function notifyTcgShopReviewers(snapshot, submissionId) {
  if (!snapshot || !snapshot.exists) {
    logger.warn("TCG shop submission snapshot is missing.", { submissionId });
    return;
  }

  const submission = snapshot.data() || {};
  if (cleanLower(submission.status) !== "pending") {
    return;
  }

  // A timestamp on the submission lets the scheduled recovery job find old
  // requests while preventing the same request from repeatedly alerting admins.
  if (submission.adminNotificationAttemptedAt) {
    return;
  }

  const reviewers = await getTcgShopReviewers();
  if (reviewers.length === 0) {
    logger.warn("No admin or moderator accounts found for TCG shop request.", {
      submissionId,
    });
    return;
  }

  const shopName = cleanString(submission.name) || "A TCG shop";
  const location = [
    cleanString(submission.town),
    cleanString(submission.county),
  ].filter(Boolean).join(", ");

  const results = await sendNotificationToRecipientsOnce({
    recipients: reviewers,
    dedupePrefix: `tcg-shop-submission:${submissionId}`,
    title: "New TCG shop request",
    body: location
      ? `${shopName} in ${location} needs reviewing.`
      : `${shopName} needs reviewing.`,
    data: {
      type: "tcg_shop_submission",
      route: "admin_tcg_shop_submissions",
      submissionId,
    },
    logContext: {
      type: "tcg_shop_submission",
      submissionId,
    },
  });

  const totals = totalsFromNotificationResults(results);
  await snapshot.ref.set(
    {
      adminNotificationAttemptedAt:
        admin.firestore.FieldValue.serverTimestamp(),
      adminNotificationSuccessCount: totals.successCount,
      adminNotificationFailureCount: totals.failureCount,
      adminNotificationTokenCount: totals.tokenCount,
      adminNotificationRecipientCount: totals.recipientCount,
    },
    { merge: true }
  );
}

exports.sendTcgShopSubmissionAdminNotification = onDocumentCreated(
  {
    document: "tcg_shop_submissions/{submissionId}",
    region: REGION,
  },
  async (event) => {
    await notifyTcgShopReviewers(event.data, event.params.submissionId);
  }
);

// Covers pending submissions that were created before the push trigger was
// deployed, including requests that an admin has not yet noticed.
exports.recoverMissedTcgShopSubmissionNotifications = onSchedule(
  {
    schedule: "every 30 minutes",
    region: REGION,
    timeZone: "Europe/London",
  },
  async () => {
    const pendingSnapshot = await db
      .collection("tcg_shop_submissions")
      .where("status", "==", "pending")
      .limit(100)
      .get();

    for (const submissionDoc of pendingSnapshot.docs) {
      await notifyTcgShopReviewers(submissionDoc, submissionDoc.id);
    }

    const reviewQueues = [
      {
        collection: "feedback_reports",
        status: "new",
        type: "admin_feedback_report",
        title: "Feedback report waiting",
        route: "admin_feedback_reports",
        body: (data) =>
          `${cleanString(data.type) || "Problem"}: ${cleanString(data.screen) || "PocketChase"}`,
      },
      {
        collection: "community_reports",
        status: "open",
        type: "admin_community_report",
        title: "Community safety report waiting",
        route: "admin_community_reports",
        body: (data) =>
          `${cleanString(data.reason) || "Report"}: ${cleanString(data.targetTitle) || cleanString(data.targetType) || "Community content"}`,
      },
      {
        collection: "business_pro_requests",
        status: "pending",
        type: "admin_business_pro_request",
        title: "Business Pro request waiting",
        route: "admin_business_requests",
        body: (data) =>
          `${cleanString(data.businessName) || cleanString(data.name) || "A business"} needs reviewing.`,
      },
      {
        collection: "business_profiles",
        status: "pending",
        type: "admin_business_profile",
        title: "Business profile waiting",
        route: "admin_business_profiles",
        body: (data) =>
          `${cleanString(data.businessName) || "A business profile"} needs reviewing.`,
      },
    ];

    for (const queue of reviewQueues) {
      const queueSnapshot = await db
        .collection(queue.collection)
        .where("status", "==", queue.status)
        .limit(100)
        .get();

      for (const itemDoc of queueSnapshot.docs) {
        const data = itemDoc.data() || {};
        if (data.adminNotificationAttemptedAt) continue;
        await notifyAdminsForReviewItem({
          snapshot: itemDoc,
          itemId: itemDoc.id,
          notificationType: queue.type,
          title: queue.title,
          body: queue.body(data),
          route: queue.route,
        });
      }
    }

    const archivedPostsSnapshot = await db
      .collection("community_posts")
      .where("archivedForAdmin", "==", true)
      .limit(100)
      .get();

    for (const postDoc of archivedPostsSnapshot.docs) {
      const post = postDoc.data() || {};
      if (post.adminNotificationAttemptedAt) continue;
      await notifyAdminsForReviewItem({
        snapshot: postDoc,
        itemId: postDoc.id,
        notificationType: "admin_archived_community_post",
        title: "Archived community post waiting",
        body: `${cleanString(post.title) || "A community post"} needs admin review.`,
        route: "admin_community_archive",
      });
    }
  }
);

exports.pokewalletJapaneseImage = onRequest(
  { region: REGION, secrets: [POKEWALLET_API_KEY], timeoutSeconds: 30 },
  async (request, response) => {
    try {
      const kind = request.query.kind === "set" ? "set" : "card";
      const id = String(request.query.id || "").trim();
      if (!/^[a-zA-Z0-9_-]{1,180}$/.test(id)) {
        response.status(400).send("Invalid image identifier.");
        return;
      }
      const cachedFile = admin.storage().bucket().file(
        `pokewallet_japanese_artwork/${kind}/${id}`
      );
      try {
        const [cachedBytes] = await cachedFile.download();
        const [metadata] = await cachedFile.getMetadata();
        response.set("Content-Type", metadata.contentType || "image/jpeg");
        response.set("Cache-Control", "public, max-age=86400, s-maxage=604800");
        response.status(200).send(cachedBytes);
        return;
      } catch (_) {
        // The first request downloads and stores the image below.
      }
      const path = kind === "set"
        ? `/sets/${encodeURIComponent(id)}/image`
        : `/images/${encodeURIComponent(id)}?size=high`;
      const upstream = await fetch(`https://api.pokewallet.io${path}`, {
        headers: { "X-API-Key": POKEWALLET_API_KEY.value() },
      });
      if (!upstream.ok) {
        response.status(upstream.status).send("Artwork unavailable.");
        return;
      }
      const bytes = Buffer.from(await upstream.arrayBuffer());
      const contentType = upstream.headers.get("content-type") || "image/jpeg";
      await cachedFile.save(bytes, {
        resumable: false,
        metadata: {
          contentType,
          cacheControl: "public,max-age=31536000,immutable",
        },
      }).catch((error) => logger.warn("Could not cache Japanese artwork.", error));
      response.set("Content-Type", contentType);
      response.set("Cache-Control", "public, max-age=86400, s-maxage=604800");
      response.status(200).send(bytes);
    } catch (error) {
      logger.error("Japanese artwork proxy failed.", error);
      response.status(502).send("Artwork service unavailable.");
    }
  }
);

// Official Trade Matches proposals. Only the two participants can write or read
// these documents (see firestore.rules). Notifications are best-effort and
// deliberately do not transfer or reserve cards.
exports.sendTradeOfferCreatedNotification = onDocumentCreated(
  { document: "trade_offers/{offerId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const offer = snap.data() || {};
    const offerId = event.params.offerId;
    const recipientUid = cleanString(offer.toUid);
    const senderUid = cleanString(offer.fromUid);
    if (!recipientUid || !senderUid || recipientUid === senderUid || offer.status !== "pending") return;
    const senderName = cleanString(offer.fromName) || (await getUserDisplayName(senderUid));
    if (!(await shouldSendNotificationOnce(`trade_offer_new:${offerId}:${recipientUid}`, {
      type: "trade_offer", offerId, recipientUid,
    }))) return;
    await sendPushToUser({
      userId: recipientUid,
      title: "New PocketChase trade offer",
      body: `${senderName} wants to make a deal. Open My Trades to respond.`,
      data: { type: "trade_offer", offerId, senderUid },
      logContext: { type: "trade_offer", offerId },
    });
  }
);

exports.sendTradeOfferUpdatedNotification = onDocumentUpdated(
  { document: "trade_offers/{offerId}", region: REGION },
  async (event) => {
    const before = event.data && event.data.before && event.data.before.data();
    const after = event.data && event.data.after && event.data.after.data();
    if (!before || !after) return;
    const offerId = event.params.offerId;
    const status = cleanString(after.status);
    const changedStatus = before.status !== after.status;
    const changedFromConfirmation = !before.confirmedByFrom && after.confirmedByFrom;
    const changedToConfirmation = !before.confirmedByTo && after.confirmedByTo;
    if (!changedStatus && !changedFromConfirmation && !changedToConfirmation) return;

    // A counteroffer creates a new proposal and its own notification.
    if (status === "countered") return;
    const recipientUid = status === "completed" ? ""
      : changedFromConfirmation ? cleanString(after.toUid)
      : changedToConfirmation ? cleanString(after.fromUid)
      : status === "accepted" || status === "declined" ? cleanString(after.fromUid)
      : status === "cancelled" ? cleanString(after.toUid) : "";
    if (status === "completed") {
      for (const uid of [cleanString(after.fromUid), cleanString(after.toUid)]) {
        if (!uid) continue;
        if (!(await shouldSendNotificationOnce(`trade_offer_completed:${offerId}:${uid}`, {
          type: "trade_offer_completed", offerId, recipientUid: uid,
        }))) continue;
        await sendPushToUser({ userId: uid, title: "Trade exchange confirmed",
          body: "Both collectors confirmed the exchange. Remember to update your collections.",
          data: { type: "trade_offer", offerId },
          logContext: { type: "trade_offer_completed", offerId },
        });
      }
      return;
    }
    if (!recipientUid) return;
    const actionText = {
      accepted: "Your trade offer was accepted. Arrange the exchange in Messages.",
      declined: "Your trade offer was declined.",
      cancelled: "A trade offer was cancelled.",
    }[status] || "Your trade partner confirmed their side of the exchange.";
    const key = `trade_offer_update:${offerId}:${status}:${recipientUid}:${after.confirmedByFrom}:${after.confirmedByTo}`;
    if (!(await shouldSendNotificationOnce(key, {
      type: "trade_offer_update", offerId, recipientUid,
    }))) return;
    await sendPushToUser({ userId: recipientUid,
      title: "PocketChase trade update", body: actionText,
      data: { type: "trade_offer", offerId },
      logContext: { type: "trade_offer_update", offerId },
    });
  }
);
