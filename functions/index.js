// v2 imports
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
admin.initializeApp();

// optional defaults (region/memory/instances)
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

async function resetToday(db) {
  const snap = await db.collection('member').where('today', '>', 0).get();
  if (snap.empty) return;

  const docs = snap.docs;
  for (let i = 0; i < docs.length; i += 500) {
    const batch = db.batch();
    docs.slice(i, i + 500).forEach(doc => batch.update(doc.ref, { today: 0 }));
    await batch.commit();
  }
}

// Daily at midnight ET
exports.scheduledDailyReset = onSchedule(
  { schedule: '0 0 * * *', timeZone: 'America/New_York' },
  async (event) => {
    await resetToday(admin.firestore());
    console.log('Today fields reset');
  }
);

// Callable admin reset (note: v2 uses a single request object)
exports.adminResetToday = onCall(async (request) => {
  const auth = request.auth;
  if (!auth || auth.token?.admin !== true) {
    throw new Error('permission-denied');
  }
  await resetToday(admin.firestore());
  return { status: 'ok' };
});
