const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.sendRestockAlertNotifications = onDocumentCreated(
  "restock_alerts/{alertId}",
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

    const shopName = String(alert.shopName || "").trim();
    const productName = String(alert.productName || "").trim();
    const productUrl = String(alert.productUrl || "").trim();
    const notes = String(alert.notes || "").trim();

    if (!shopName || !productName) {
      logger.warn("Restock alert is missing shopName or productName.", {
        alertId,
      });
      return;
    }

    const enabledUsersSnapshot = await db
      .collection("user_feature_flags")
      .where("restockAlertsEnabled", "==", true)
      .get();

    if (enabledUsersSnapshot.empty) {
      logger.info("No users have Restock Alerts enabled.", { alertId });
      return;
    }

    const tokenRefsByToken = new Map();
    const tokenReadPromises = [];

    enabledUsersSnapshot.docs.forEach((userFlagDoc) => {
      const userId = userFlagDoc.id;

      tokenReadPromises.push(
        db
          .collection("users")
          .doc(userId)
          .collection("fcmTokens")
          .get()
          .then((tokensSnapshot) => {
            tokensSnapshot.docs.forEach((tokenDoc) => {
              const token = String(tokenDoc.data().token || "").trim();

              if (token) {
                tokenRefsByToken.set(token, tokenDoc.ref);
              }
            });
          })
      );
    });

    await Promise.all(tokenReadPromises);

    const tokens = Array.from(tokenRefsByToken.keys());

    if (tokens.length === 0) {
      logger.info("No FCM tokens found for enabled users.", { alertId });
      return;
    }

    const title = `${productName} is back in stock`;
    const body = notes ? `${shopName} • ${notes}` : shopName;

    let successCount = 0;
    let failureCount = 0;
    const invalidTokenDeletePromises = [];

    for (let index = 0; index < tokens.length; index += 500) {
      const tokenBatch = tokens.slice(index, index + 500);

      const response = await messaging.sendEachForMulticast({
        tokens: tokenBatch,
        notification: {
          title,
          body,
        },
        data: {
          type: "restock",
          alertId,
          shopName,
          productName,
          productUrl,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "pocketchase_notifications",
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

        logger.warn("Failed to send restock notification.", {
          alertId,
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

    await snapshot.ref.set(
      {
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationSuccessCount: successCount,
        notificationFailureCount: failureCount,
        notificationTokenCount: tokens.length,
      },
      { merge: true }
    );

    logger.info("Restock notifications sent.", {
      alertId,
      successCount,
      failureCount,
      tokenCount: tokens.length,
    });
  }
);
