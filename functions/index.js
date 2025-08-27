const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

async function resetToday(db) {
  const snapshot = await db.collection('member').where('today', '!=', 0).get();
  if (snapshot.empty) {
    return;
  }
  const batch = db.batch();
  snapshot.forEach(doc => {
    batch.update(doc.ref, { today: 0 });
  });
  await batch.commit();
}

exports.scheduledDailyReset = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('Asia/Seoul')
  .onRun(async () => {
    await resetToday(admin.firestore());
    console.log('Today fields reset');
  });

exports.adminResetToday = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin privileges required.');
  }
  await resetToday(admin.firestore());
  return { status: 'ok' };
});
