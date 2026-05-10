const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const REGION = "europe-west2";
const NOTIFICATION_CHANNEL_ID = "pocketchase_notifications";

const DEFAULT_CHECK_TIMEOUT_MS = 20000;

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
