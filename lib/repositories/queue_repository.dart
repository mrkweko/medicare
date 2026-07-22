import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/failures.dart';
import '../core/supabase/supabase_init.dart';
import '../models/queue_entry_model.dart';

class QueueRepository {
  QueueRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    SupabaseClient? supabaseClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _supabase = supabaseClient ?? supabase;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final SupabaseClient _supabase;

  /// Appointment status syncs go to Supabase (Step 5). Queue entries remain
  /// on Firestore until Step 6.
  ///
  /// FIX NOT APPLIED YET (deferred to Step 6 RPC): check-in is still a
  /// non-transactional dual-write (Firestore queue entry + Supabase
  /// appointment). If the second write fails, state can diverge.
  Future<void> _syncAppointmentStatus({
    required String appointmentId,
    required String status,
    bool setCheckedInAt = false,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      if (setCheckedInAt) 'checked_in_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _supabase.from('appointments').update(payload).eq('id', appointmentId);
  }

  Future<String> checkIn({
    required String appointmentId,
    required String patientId,
    required String patientName,
    String? patientPhoneNumber,
    String? doctorId,
    required int tokenNumber,
    required String hospitalId,
    required String date,
    required String departmentId,
    String priority = 'normal',
  }) async {
    try {
      final entry = QueueEntryModel(
        id: '',
        appointmentId: appointmentId,
        patientId: patientId,
        patientName: patientName,
        patientPhoneNumber: patientPhoneNumber,
        doctorId: doctorId ?? '',
        tokenNumber: tokenNumber,
        priority: priority,
        status: 'waiting',
      );

      final collectionRef = _firestore.collection(
        FirestorePaths.queueEntriesCollection(hospitalId: hospitalId, date: date, departmentId: departmentId),
      );
      final docRef = await collectionRef.add(entry.toMap());
      await _syncAppointmentStatus(
        appointmentId: appointmentId,
        status: 'checked_in',
        setCheckedInAt: true,
      );
      return docRef.id;
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Check-in failed', code: e.code);
    } on PostgrestException catch (e) {
      throw DataFailure(e.message, code: e.code);
    }
  }

  Future<void> updateStatus({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String entryId,
    required String status,
  }) async {
    final ref = _firestore.doc(
      FirestorePaths.queueEntry(hospitalId: hospitalId, date: date, departmentId: departmentId, entryId: entryId),
    );

    final snap = await ref.get();
    if (!snap.exists) throw const DataFailure('Queue entry no longer exists.');
    final data = snap.data()!;
    final currentStatus = data['status'] as String? ?? 'waiting';

    final allowed = _allowedTransitions[currentStatus] ?? [];
    if (!allowed.contains(status)) {
      throw DataFailure('Cannot move from "$currentStatus" to "$status" — invalid transition.');
    }

    final fieldsByStatus = {
      'in_consultation': 'consultationStartedAt',
      'completed': 'consultationCompletedAt',
    };
    try {
      await ref.update({
        'status': status,
        if (fieldsByStatus[status] != null) fieldsByStatus[status]!: FieldValue.serverTimestamp(),
        if (status == 'in_consultation') 'warnedAt': null,
        if (status == 'in_consultation') 'graceDeadline': null,
      });

      // Sync forward onto the appointment — closes the long-standing gap
      // where appointments.status never advanced past 'checked_in' even
      // after a patient was fully seen. Only 'completed' is synced (not
      // 'called'/'in_consultation'/'paused' — those are live-queue-only
      // states with no equivalent meaning on the appointment level).
      if (status == 'completed') {
        final appointmentId = data['appointmentId'] as String?;
        if (appointmentId != null) {
          await _syncAppointmentStatus(appointmentId: appointmentId, status: 'completed');
        }
      }
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to update status', code: e.code);
    } on PostgrestException catch (e) {
      throw DataFailure(e.message, code: e.code);
    }
  }

  Future<void> markSkipped({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String entryId,
  }) async {
    try {
      final ref = _firestore.doc(
        FirestorePaths.queueEntry(hospitalId: hospitalId, date: date, departmentId: departmentId, entryId: entryId),
      );
      final snap = await ref.get();
      final appointmentId = snap.data()?['appointmentId'] as String?;

      await ref.update({
        'status': 'skipped',
        'doctorId': '',
        'skippedAt': FieldValue.serverTimestamp(),
      });

      if (appointmentId != null) {
        await _syncAppointmentStatus(appointmentId: appointmentId, status: 'skipped');
      }
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to mark skipped', code: e.code);
    } on PostgrestException catch (e) {
      throw DataFailure(e.message, code: e.code);
    }
  }



  /// Receptionist escalates an already-queued patient in place — no
  /// re-booking, per SRS Section 3. Direct Firestore write (isStaffOf
  /// already permits update on queue_entries), not a callable — this is a
  /// single-document write, no atomicity concern like callNextPatient has.
  Future<void> escalatePriority({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String entryId,
    required String newPriority, // 'critical' | 'urgent'
  }) async {
    const priorityRanks = {'critical': 0, 'urgent': 1, 'normal': 2};
    try {
      await _firestore
          .doc(FirestorePaths.queueEntry(hospitalId: hospitalId, date: date, departmentId: departmentId, entryId: entryId))
          .update({
        'priority': newPriority,
        'priorityRank': priorityRanks[newPriority] ?? 2,
      });
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to escalate priority', code: e.code);
    }
  }

  Stream<List<QueueEntryModel>> watchLiveQueue({
    required String hospitalId,
    required String date,
    required String departmentId,
  }) {
    return _firestore
        .collection(FirestorePaths.queueEntriesCollection(hospitalId: hospitalId, date: date, departmentId: departmentId))
        .where('status', whereIn: ['waiting', 'called', 'in_consultation'])
        .orderBy('checkedInAt')
        .snapshots()
        .map((snap) {
      final entries = snap.docs.map(QueueEntryModel.fromFirestore).toList();
      const priorityRank = {'critical': 0, 'urgent': 1, 'normal': 2};
      entries.sort((a, b) => priorityRank[a.priority]!.compareTo(priorityRank[b.priority]!));
      return entries;
    });
  }

  /// Two equality filters (doctorId, status), no orderBy — no composite
  /// index needed, unlike callNextPatient's compound query. Scoped to a
  /// specific doctor's own completions today, not the whole department.
  Stream<int> watchCompletedCountForDoctorToday({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String doctorId,
  }) {
    return _firestore
        .collection(FirestorePaths.queueEntriesCollection(hospitalId: hospitalId, date: date, departmentId: departmentId))
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Doctor says "I'm ready" — the server (not the doctor) decides who's
  /// actually next, per FIFO + priority, or a recurring follow-up they're
  /// already committed to. See functions/src/callNextPatient.js.
  Future<({String entryId, int tokenNumber})> callNextPatient({
    required String hospitalId,
    required String date,
  }) async {
    try {
      final result = await _functions.httpsCallable('callNextPatient').call<Map<String, dynamic>>({
        'hospitalId': hospitalId,
        'date': date,
      });
      return (entryId: result.data['entryId'] as String, tokenNumber: result.data['tokenNumber'] as int);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw const DataFailure('No patients waiting.', code: 'not-found');
      }
      throw DataFailure(e.message ?? 'Failed to call next patient', code: e.code);
    }
  }

  static const Map<String, List<String>> _allowedTransitions = {
    'waiting': ['called', 'skipped'],
    'called': ['in_consultation', 'skipped'],
    'in_consultation': ['completed', 'paused'],
    'paused': ['in_consultation'],
    'skipped': ['waiting'], // via rejoinPatient, not updateStatus directly
    'completed': [], // terminal
  };

  Future<({int graceMinutes, int graceDeadlineMillis})> warnPatientDelay({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String entryId,
  }) async {
    try {
      final result = await _functions.httpsCallable('warnPatientDelay').call<Map<String, dynamic>>({
        'hospitalId': hospitalId,
        'date': date,
        'departmentId': departmentId,
        'entryId': entryId,
      });
      return (
      graceMinutes: (result.data['graceMinutes'] as num).toInt(),
      graceDeadlineMillis: (result.data['graceDeadlineMillis'] as num).toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw DataFailure(e.message ?? 'Failed to warn patient', code: e.code);
    }
  }




  Stream<List<QueueEntryModel>> watchSkippedEntries({
    required String hospitalId,
    required String date,
    required String departmentId,
  }) {
    return _firestore
        .collection(FirestorePaths.queueEntriesCollection(hospitalId: hospitalId, date: date, departmentId: departmentId))
        .where('status', isEqualTo: 'skipped')
        .snapshots()
        .map((snap) => snap.docs.map(QueueEntryModel.fromFirestore).toList());
  }

  /// A patient's own live queue entry, if they're checked in anywhere
  /// today — reuses watchLiveQueue's existing sort (priority, then
  /// checkedInAt) to derive their position, rather than duplicating that
  /// logic. Returns null entry/position if they're not currently queued.
  /// Scoped directly to the calling patient — no unscoped department-wide
  /// query. patientsAhead is read straight off their own doc, written by
  /// onQueueEntryWritten's resequencing loop (see queueNotifications.js).
  Stream<QueueEntryModel?> watchMyQueueStatus({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String patientId,
  }) {
    return _firestore
        .collection(FirestorePaths.queueEntriesCollection(hospitalId: hospitalId, date: date, departmentId: departmentId))
        .where('patientId', isEqualTo: patientId)
        .where('status', whereIn: ['waiting', 'called', 'in_consultation'])
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : QueueEntryModel.fromFirestore(snap.docs.first));
  }

  /// Rejoins a skipped patient per the hospital's configured skip policy.
  /// Since position is always derived from (priorityRank, checkedInAt) sort
  /// order, repositioning is done purely by rewriting checkedInAt — no
  /// separate "position" field exists to update.
  Future<void> rejoinPatient({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String entryId,
    required String skipPolicy, // 'end_of_queue' | 'after_current'
    required String priority,
  }) async {
    try {
      final entryRef = _firestore.doc(
        FirestorePaths.queueEntry(hospitalId: hospitalId, date: date, departmentId: departmentId, entryId: entryId),
      );

      Timestamp newCheckedInAt;
      if (skipPolicy == 'after_current') {
        // Place first within their own priority tier — earlier than every
        // other currently-waiting entry, so they sort ahead of the rest of
        // their tier without jumping a higher-priority tier.
        final waitingSnap = await _firestore
            .collection(FirestorePaths.queueEntriesCollection(hospitalId: hospitalId, date: date, departmentId: departmentId))
            .where('status', isEqualTo: 'waiting')
            .orderBy('checkedInAt')
            .limit(1)
            .get();

        final earliest = waitingSnap.docs.isNotEmpty
            ? (waitingSnap.docs.first.data()['checkedInAt'] as Timestamp?)
            : null;
        newCheckedInAt = earliest != null
            ? Timestamp.fromMillisecondsSinceEpoch(earliest.millisecondsSinceEpoch - 1000)
            : Timestamp.now();
      } else {
        // end_of_queue — just re-stamp to now, same as a fresh check-in.
        newCheckedInAt = Timestamp.now();
      }

      await entryRef.update({
        'status': 'waiting',
        'checkedInAt': newCheckedInAt,
        'lastNotifiedThreshold': 'none', // fresh queue journey — see progress notes
      });
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to rejoin patient', code: e.code);
    }
  }

  Future<void> pauseConsultation({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String entryId,
  }) async {
    try {
      await _firestore
          .doc(FirestorePaths.queueEntry(hospitalId: hospitalId, date: date, departmentId: departmentId, entryId: entryId))
          .update({
        'status': 'paused',
        'pausedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to pause consultation', code: e.code);
    }
  }

  /// Resumes with the SAME doctor — doctorId was never cleared on pause,
  /// unlike Skip. Accumulates elapsed pause time into totalPausedMs so
  /// consultationAverages.js can exclude it from the duration calc.
  Future<void> resumeConsultation({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String entryId,
  }) async {
    final ref = _firestore.doc(
      FirestorePaths.queueEntry(hospitalId: hospitalId, date: date, departmentId: departmentId, entryId: entryId),
    );
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw const DataFailure('Queue entry no longer exists.');
        final data = snap.data()!;

        final pausedAt = data['pausedAt'] as Timestamp?;
        final elapsedMs = pausedAt != null ? DateTime.now().millisecondsSinceEpoch - pausedAt.millisecondsSinceEpoch : 0;
        final existingPausedMs = (data['totalPausedMs'] as num?)?.toInt() ?? 0;

        tx.update(ref, {
          'status': 'in_consultation',
          'pausedAt': null,
          'totalPausedMs': existingPausedMs + elapsedMs,
        });
      });
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to resume consultation', code: e.code);
    }
  }

  Stream<List<QueueEntryModel>> watchPausedEntriesForDoctor({
    required String hospitalId,
    required String date,
    required String departmentId,
    required String doctorId,
  }) {
    return _firestore
        .collection(FirestorePaths.queueEntriesCollection(hospitalId: hospitalId, date: date, departmentId: departmentId))
        .where('status', isEqualTo: 'paused')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snap) => snap.docs.map(QueueEntryModel.fromFirestore).toList());
  }

}