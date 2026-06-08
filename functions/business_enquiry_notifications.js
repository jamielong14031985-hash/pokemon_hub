const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function trim(value) {
  return (value || "").toString().trim();
}

function notificationBody(senderName, subject) {
  const cleanSenderName = trim(senderName);
  const cleanSubject = trim(subject);

  if (cleanSenderName && cleanSubject) {
    return `${cleanSenderName}: ${cleanSubject}`;
  }

  if (cleanSubject) {
    return cleanSubject;
  }

  if (cleanSenderName) {
    return `${cleanSenderName} sent a new enquiry.`;
  }

  return "A customer sent a new enquiry.";
}

exports.sendBusinessEnquiryNotification = functions.firestore
  .document("business_profiles/{businessId}/enquiries/{enquiryId}")
  .onCreate(async (snapshot, context) => {
    const enquiry = snapshot.data() || {};
    const businessId = context.params.businessId;
    const enquiryId = context.params.enquiryId;

    let ownerUid = trim(enquiry.businessOwnerUid);
    let businessName = trim(enquiry.businessName);

    if (!ownerUid || !businessName) {
      const businessSnapshot = await db
        .collection("business_profiles")
        .doc(businessId)
        .get();

      const business = businessSnapshot.data() || {};
      ownerUid = ownerUid || trim(business.ownerUid);
      businessName = businessName || trim(business.businessName);
    }

    if (!ownerUid) {
      functions.logger.warn("Business enquiry notification skipped: missing owner uid", {
        businessId,
        enquiryId,
      });
      return null;
    }

    const tokensSnapshot = await db
      .collection("users")
      .doc(ownerUid)
      .collection("fcmTokens")
      .get();

    if (tokensSnapshot.empty) {
      functions.logger.info("Business enquiry notification skipped: owner has no FCM tokens", {
        businessId,
        enquiryId,
        ownerUid,
      });
      return null;
    }

    const tokenDocs = [];
    const tokens = [];

    tokensSnapshot.docs.forEach((doc) => {
      const token = trim(doc.get("token"));
      if (token) {
        tokenDocs.push(doc);
        tokens.push(token);
      }
    });

    if (tokens.length === 0) {
      return null;
    }

    const subject = trim(enquiry.subject) || "New enquiry";
    const senderName = trim(enquiry.senderName);
    const title = businessName
      ? `New enquiry for ${businessName}`
      : "New business enquiry";

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body: notificationBody(senderName, subject),
      },
      data: {
        type: "business_enquiry",
        businessId,
        enquiryId,
        route: "business_enquiries",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "business_enquiries",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
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

    const invalidCodes = new Set([
      "messaging/invalid-registration-token",
      "messaging/registration-token-not-registered",
    ]);

    const batch = db.batch();
    let invalidTokenCount = 0;

    response.responses.forEach((sendResponse, index) => {
      const errorCode = sendResponse.error && sendResponse.error.code;

      if (errorCode && invalidCodes.has(errorCode)) {
        invalidTokenCount += 1;
        batch.delete(tokenDocs[index].ref);
      }
    });

    if (invalidTokenCount > 0) {
      await batch.commit();
    }

    functions.logger.info("Business enquiry notification sent", {
      businessId,
      enquiryId,
      ownerUid,
      successCount: response.successCount,
      failureCount: response.failureCount,
      invalidTokenCount,
    });

    return null;
  });
