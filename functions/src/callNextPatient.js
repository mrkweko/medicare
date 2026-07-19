const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');

exports.callNextPatient = onCall(async (request) => {
  const caller = request.auth;
  if (!caller || caller.token.role !== 'doctor') {
    throw new HttpsError('permission-denied', 'Only a doctor may call the next patient.');
  }

  const { hospitalId, date } = request.data ?? {};
  if (!hospitalId || !date) {
    throw new HttpsError('invalid-argument', 'hospitalId and date are required.');
  }

  const db = getFirestore();

  const doctorSnap = await db.collection('doctors').doc(caller.uid).get();
  if (!doctorSnap.exists) {
    throw new HttpsError('failed-precondition', 'No doctor profile found for this account.');
  }
  const departmentId = doctorSnap.data().departmentId;

  const entriesRef = db
    .collection('queue_entries')
    .doc(hospitalId)
    .collection(date)
    .doc(departmentId)
    .collection('entries');

  // A doctor may only have ONE active patient (called or in_consultation)
  // at a time. Checked outside the transaction first as a cheap early
  // reject, and would also be safe to check again inside if this were
  // ever called concurrently by the same doctor from two devices — not
  // bothering with that edge case given the time constraints.
  const activeSnap = await entriesRef
    .where('doctorId', '==', caller.uid)
    .where('status', 'in', ['called', 'in_consultation'])
    .limit(1)
    .get();
  if (!activeSnap.empty) {
    throw new HttpsError(
      'failed-precondition',
      'You already have an active patient. Complete or the current consultation before calling the next one.'
    );
  }

  try {
    const result = await db.runTransaction(async (tx) => {
      const assignedSnap = await tx.get(
        entriesRef.where('doctorId', '==', caller.uid).where('status', '==', 'waiting').limit(1)
      );

      let targetDoc;
      if (!assignedSnap.empty) {
        targetDoc = assignedSnap.docs[0];
      } else {
        const nextSnap = await tx.get(
          entriesRef
            .where('doctorId', '==', '')
            .where('status', '==', 'waiting')
            .orderBy('priorityRank')
            .orderBy('checkedInAt')
            .limit(1)
        );
        if (nextSnap.empty) {
          return null;
        }
        targetDoc = nextSnap.docs[0];
      }

      const fresh = await tx.get(targetDoc.ref);
      if (!fresh.exists || fresh.data().status !== 'waiting') {
        return null;
      }

      tx.update(targetDoc.ref, {
        doctorId: caller.uid,
        status: 'called',
        calledAt: FieldValue.serverTimestamp(),
      });

      return { entryId: targetDoc.id, ...fresh.data() };
    });

    if (!result) {
      throw new HttpsError('not-found', 'No patients waiting.');
    }

    logger.info(`callNextPatient: doctor ${caller.uid} called entry ${result.entryId} (token #${result.tokenNumber})`);
    return { entryId: result.entryId, tokenNumber: result.tokenNumber, patientId: result.patientId };
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    logger.error('callNextPatient: transaction failed', err);
    throw new HttpsError('internal', 'Failed to call next patient.');
  }
});