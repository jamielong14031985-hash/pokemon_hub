const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const REGION = 'europe-west2';

function clean(value) {
  return String(value || '').trim();
}

async function assertAdminOrModerator(uid, token) {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Please sign in first.');
  }

  const claims = token || {};
  if (claims.admin === true || claims.moderator === true) {
    return;
  }

  const roleSnapshot = await db.collection('app_roles').doc(uid).get();
  const roleData = roleSnapshot.data() || {};
  const role = clean(roleData.role || roleData.type).toLowerCase();

  if (
    role === 'admin' ||
    role === 'moderator' ||
    roleData.admin === true ||
    roleData.isAdmin === true ||
    roleData.moderator === true ||
    roleData.isModerator === true
  ) {
    return;
  }

  throw new HttpsError(
    'permission-denied',
    'Only admins and moderators can approve shop requests.',
  );
}

function cleanApprovedShopData(submissionData, submissionId, uid) {
  const now = admin.firestore.FieldValue.serverTimestamp();

  const shopData = {
    ...submissionData,
    status: 'approved',
    verified: true,
    source: submissionData.source || 'user_submission',
    sourceSubmissionId: submissionId,
    approvedAt: now,
    approvedBy: uid,
    updatedAt: now,
    createdAt: submissionData.createdAt || now,
  };

  delete shopData.submittedBy;
  delete shopData.submittedByEmail;
  delete shopData.updatedAtMs;
  delete shopData.createdAtMs;
  delete shopData.rejectedAt;
  delete shopData.rejectedBy;

  return shopData;
}

exports.adminApproveTcgShopSubmission = onCall(
  {
    region: REGION,
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    const uid = request.auth && request.auth.uid ? request.auth.uid : '';
    await assertAdminOrModerator(uid, request.auth && request.auth.token);

    const submissionId = clean(request.data && request.data.submissionId);
    if (!submissionId) {
      throw new HttpsError('invalid-argument', 'Missing shop request ID.');
    }

    const submissionRef = db.collection('tcg_shop_submissions').doc(submissionId);
    const submissionSnapshot = await submissionRef.get();

    if (!submissionSnapshot.exists) {
      throw new HttpsError(
        'not-found',
        'This shop request has already been removed or cannot be found.',
      );
    }

    const submissionData = submissionSnapshot.data() || {};
    const status = clean(submissionData.status || 'pending').toLowerCase();

    if (status !== 'pending') {
      throw new HttpsError(
        'failed-precondition',
        `This shop request is already marked as ${status}.`,
      );
    }

    const shopData = cleanApprovedShopData(submissionData, submissionId, uid);
    const shopRef = db.collection('tcg_shops').doc(submissionId);

    const batch = db.batch();
    batch.set(shopRef, shopData, { merge: true });
    batch.delete(submissionRef);
    await batch.commit();

    logger.info('TCG shop request approved.', {
      submissionId,
      uid,
      name: clean(submissionData.name),
    });

    return {
      ok: true,
      status: 'approved',
      shopId: shopRef.id,
    };
  },
);

exports.adminRejectTcgShopSubmission = onCall(
  {
    region: REGION,
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    const uid = request.auth && request.auth.uid ? request.auth.uid : '';
    await assertAdminOrModerator(uid, request.auth && request.auth.token);

    const submissionId = clean(request.data && request.data.submissionId);
    if (!submissionId) {
      throw new HttpsError('invalid-argument', 'Missing shop request ID.');
    }

    const submissionRef = db.collection('tcg_shop_submissions').doc(submissionId);
    const submissionSnapshot = await submissionRef.get();

    if (!submissionSnapshot.exists) {
      return {
        ok: true,
        status: 'already_removed',
      };
    }

    await submissionRef.delete();

    logger.info('TCG shop request rejected.', {
      submissionId,
      uid,
      name: clean((submissionSnapshot.data() || {}).name),
    });

    return {
      ok: true,
      status: 'rejected',
    };
  },
);
