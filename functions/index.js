const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
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