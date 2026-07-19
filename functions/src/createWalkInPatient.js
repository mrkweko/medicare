const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');

// SRS 2.3: receptionist creates a patient record for someone without a
// smartphone. They get a real Auth account (so patientId/uid works
// identically everywhere else in the data model) but likely never log in —
// no password is set, email is optional. createUser() with neither is
// valid via the Admin SDK, unlike the client SDK.
exports.createWalkInPatient = onCall(async (request) => {
  const caller = request.auth;
  if (!caller || caller.token.role !== 'receptionist') {
    throw new HttpsError('permission-denied', 'Only a receptionist may create a walk-in patient record.');
  }

  const { displayName, phoneNumber, email } = request.data ?? {};
  if (!displayName) {
    throw new HttpsError('invalid-argument', 'displayName is required.');
  }

  const auth = getAuth();
  const db = getFirestore();

  let userRecord;
  try {
    userRecord = await auth.createUser({
      displayName,
      ...(phoneNumber ? { phoneNumber } : {}),
      ...(email ? { email } : {}),
    });
  } catch (err) {
    logger.error('createWalkInPatient: auth.createUser failed', err);
    if (err.code === 'auth/phone-number-already-exists' || err.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'A patient with this phone/email already exists.');
    }
    throw new HttpsError('internal', 'Failed to create patient record.');
  }

  try {
    await auth.setCustomUserClaims(userRecord.uid, { role: 'patient', hospitalId: null });
    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: email ?? null,
      phoneNumber: phoneNumber ?? null,
      displayName,
      role: 'patient',
      hospitalId: null,
      hasNoLoginCredentials: !email, // flag so UI can distinguish walk-in-only patients later
      createdAt: FieldValue.serverTimestamp(),
      createdBy: caller.uid,
    });
  } catch (err) {
    logger.error('createWalkInPatient: post-creation setup failed, rolling back', err);
    await auth.deleteUser(userRecord.uid).catch((e) => logger.error('rollback failed', e));
    throw new HttpsError('internal', 'Patient setup failed; record was not created.');
  }

  return { uid: userRecord.uid };
});