const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');

const THRESHOLD_ORDER = ['none', 'five_ahead', 'fifteen_min', 'next'];
const thresholdRank = (t) => THRESHOLD_ORDER.indexOf(t ?? 'none');

async function getDepartmentAvgConsultationMinutes(db, hospitalId, departmentId) {
  const snap = await db
    .collection('doctors')
    .where('hospitalId', '==', hospitalId)
    .where('departmentId', '==', departmentId)
    .get();
  if (snap.empty) return 15;
  const total = snap.docs.reduce((sum, d) => sum + (d.data().avgConsultationMinutes ?? 15), 0);
  return Math.round(total / snap.docs.length);
}

function messageForThreshold(threshold, patientsAhead) {
  switch (threshold) {
    case 'five_ahead':
      return `You have ${patientsAhead} patient(s) ahead of you in the queue.`;
    case 'fifteen_min':
      return `Your estimated wait is about 15 minutes. Please make your way to the hospital if you haven't already.`;
    case 'next':
      return `You're next in line. Please be ready.`;
    default:
      return null;
  }
}

async function dispatchNotification(db, { userId, type, message, hospitalId, appointmentId, queueEntryId }) {
  await db.collection('notifications').add({
    userId,
    type,
    message,
    hospitalId,
    appointmentId: appointmentId ?? null,
    queueEntryId: queueEntryId ?? null,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const userSnap = await db.collection('users').doc(userId).get();
  const phoneNumber = userSnap.exists ? userSnap.data().phoneNumber : null;
  if (phoneNumber) {
    await db.collection('sms_emulator').add({
      phoneNumber,
      message,
      relatedUserId: userId,
      relatedAppointmentId: appointmentId ?? null,
      status: 'sent',
      createdAt: FieldValue.serverTimestamp(),
    });
  }
}

exports.onQueueEntryWritten = onDocumentWritten(
  'queue_entries/{hospitalId}/{date}/{departmentId}/entries/{entryId}',
  async (event) => {
    const { hospitalId, date, departmentId, entryId } = event.params;
    const db = getFirestore();

    const beforeSnap = event.data?.before;
    const before = beforeSnap?.data();
    const after = event.data?.after?.data();
    const isCreate = !beforeSnap?.exists;

    // "You're being called" — unchanged from before.
    if (after && after.status === 'called' && before?.status !== 'called') {
      await dispatchNotification(db, {
        userId: after.patientId,
        type: 'called',
        message: `You're being called now — please proceed to the department.`,
        hospitalId,
        appointmentId: after.appointmentId,
        queueEntryId: entryId,
      });
    }

    // "Consultation completed" — new.
    if (after && after.status === 'completed' && before?.status !== 'completed') {
      await dispatchNotification(db, {
        userId: after.patientId,
        type: 'completed',
        message: `Your consultation is complete. Thank you for visiting.`,
        hospitalId,
        appointmentId: after.appointmentId,
        queueEntryId: entryId,
      });
    }

    // "Wait time updated due to an emergency case" — fires on either:
        // (a) a brand-new high-priority check-in (create), or
        // (b) an existing waiting entry being escalated to high priority
        //     in place (update) — receptionist "escalate" action, no re-booking.
        // Either way, every OTHER waiting entry with a worse priorityRank than
        // the (now-)high-priority entry gets notified.
        const isEscalation =
          !isCreate &&
          after &&
          before &&
          after.status === 'waiting' &&
          (after.priority === 'critical' || after.priority === 'urgent') &&
          after.priorityRank < (before.priorityRank ?? after.priorityRank);

        const isNewHighPriorityCheckIn =
          isCreate && after && after.status === 'waiting' && (after.priority === 'critical' || after.priority === 'urgent');

        if (isNewHighPriorityCheckIn || isEscalation) {
          const entriesRef = db
            .collection('queue_entries')
            .doc(hospitalId)
            .collection(date)
            .doc(departmentId)
            .collection('entries');

          const bumpedSnap = await entriesRef
            .where('status', '==', 'waiting')
            .where('priorityRank', '>', after.priorityRank)
            .get();

          for (const doc of bumpedSnap.docs) {
            if (doc.id === entryId) continue;
            await dispatchNotification(db, {
              userId: doc.data().patientId,
              type: 'priority_bump',
              message: `Your wait time has been updated due to an emergency case being prioritized ahead of you.`,
              hospitalId,
              appointmentId: doc.data().appointmentId,
              queueEntryId: doc.id,
            });
          }
        }

    // Full-department resequence + threshold escalation — unchanged from before.
    const entriesRef = db
      .collection('queue_entries')
      .doc(hospitalId)
      .collection(date)
      .doc(departmentId)
      .collection('entries');

    const waitingSnap = await entriesRef
      .where('status', '==', 'waiting')
      .orderBy('priorityRank')
      .orderBy('checkedInAt')
      .get();

    if (waitingSnap.empty) return;

    const avgMinutes = await getDepartmentAvgConsultationMinutes(db, hospitalId, departmentId);
    const batch = db.batch();
    let hasWrites = false;

    for (let i = 0; i < waitingSnap.docs.length; i++) {
      const doc = waitingSnap.docs[i];
      const data = doc.data();
      const patientsAhead = i;

      const estimatedWaitMinutes = patientsAhead * avgMinutes;
      let newThreshold = 'none';
      if (patientsAhead === 0) newThreshold = 'next';
      else if (estimatedWaitMinutes <= 15) newThreshold = 'fifteen_min';
      else if (patientsAhead <= 5) newThreshold = 'five_ahead';

      const currentThreshold = data.lastNotifiedThreshold ?? 'none';
      if (thresholdRank(newThreshold) > thresholdRank(currentThreshold)) {
        batch.update(doc.ref, { lastNotifiedThreshold: newThreshold });
        hasWrites = true;

        const message = messageForThreshold(newThreshold, patientsAhead);
        if (message) {
          await dispatchNotification(db, {
            userId: data.patientId,
            type: `queue_${newThreshold}`,
            message,
            hospitalId,
            appointmentId: data.appointmentId,
            queueEntryId: doc.id,
          });
        }
      }
    }

    if (hasWrites) {
      await batch.commit();
      logger.info(`onQueueEntryWritten: updated thresholds for ${hospitalId}/${date}/${departmentId}`);
    }
  }
);