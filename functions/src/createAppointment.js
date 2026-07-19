const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');

exports.createAppointment = onCall(async (request) => {
  const caller = request.auth;
  if (!caller) throw new HttpsError('unauthenticated', 'Must be signed in.');

  const { patientId, hospitalId, departmentId, doctorId, scheduledDate, scheduledTimeSlot } =
    request.data ?? {};

  // doctorId intentionally NOT required — see progress doc: doctor is
  // assigned in real time at call-time from a shared department queue,
  // not chosen at booking. It's only ever pre-set here for a recurring
  // follow-up (continuity of care, SRS 5) — not yet wired up client-side.
  if (!hospitalId || !departmentId || !scheduledDate) {
    throw new HttpsError('invalid-argument', 'hospitalId, departmentId, and scheduledDate are required.');
  }

  const callerRole = caller.token.role;
  const callerHospitalId = caller.token.hospitalId ?? null;

  let resolvedPatientId;
  if (callerRole === 'patient') {
    resolvedPatientId = caller.uid;
  } else if (callerRole === 'receptionist') {
    if (callerHospitalId !== hospitalId) {
      throw new HttpsError('permission-denied', 'Cannot book outside your own hospital.');
    }
    if (!patientId) {
      throw new HttpsError('invalid-argument', 'patientId is required when a receptionist books on a patient\'s behalf.');
    }
    resolvedPatientId = patientId;
  } else {
    throw new HttpsError('permission-denied', 'Only a patient or a receptionist may create an appointment.');
  }

  const db = getFirestore();
  const counterId = `${hospitalId}_${departmentId}_${scheduledDate}`;
  const counterRef = db.collection('counters').doc(counterId);
  const appointmentRef = db.collection('appointments').doc();

  try {
    const tokenNumber = await db.runTransaction(async (tx) => {
      const counterSnap = await tx.get(counterRef);
      const lastToken = counterSnap.exists ? (counterSnap.data().lastToken ?? 0) : 0;
      const nextToken = lastToken + 1;

      tx.set(
        counterRef,
        { hospitalId, departmentId, date: scheduledDate, lastToken: nextToken, updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );

      tx.set(appointmentRef, {
        patientId: resolvedPatientId,
        hospitalId,
        departmentId,
        doctorId: doctorId ?? null, // null unless this is a recurring follow-up
        scheduledDate,
        scheduledTimeSlot: scheduledTimeSlot ?? null,
        tokenNumber: nextToken,
        status: 'booked',
        visitId: null,
        isRecurring: false,
        recurringParentId: null,
        bookedBy: caller.uid,
        createdAt: FieldValue.serverTimestamp(),
      });

      return nextToken;
    });

    logger.info(`createAppointment: ${appointmentRef.id} booked, token=${tokenNumber}, patient=${resolvedPatientId}`);
    return { appointmentId: appointmentRef.id, tokenNumber };
  } catch (err) {
    logger.error('createAppointment: transaction failed', err);
    throw new HttpsError('internal', 'Failed to book appointment.');
  }
});