import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/failures.dart';
import '../core/constants/firestore_paths.dart';
import '../models/appointment_model.dart';

class AppointmentRepository {
  AppointmentRepository({FirebaseFunctions? functions, FirebaseFirestore? firestore})
      : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<({String appointmentId, int tokenNumber})> createAppointment({
    String? patientId,
    required String hospitalId,
    required String departmentId,
    String? doctorId, // only meaningful for a recurring follow-up
    required String scheduledDate,
    String? scheduledTimeSlot,
  }) async {
    try {
      final result = await _functions.httpsCallable('createAppointment').call<Map<String, dynamic>>({
        'patientId': patientId,
        'hospitalId': hospitalId,
        'departmentId': departmentId,
        'doctorId': doctorId,
        'scheduledDate': scheduledDate,
        'scheduledTimeSlot': scheduledTimeSlot,
      });
      return (appointmentId: result.data['appointmentId'] as String, tokenNumber: result.data['tokenNumber'] as int);
    } on FirebaseFunctionsException catch (e) {
      throw DataFailure(e.message ?? 'Failed to book appointment', code: e.code);
    }
  }

  Future<AppointmentModel?> fetchAppointmentById(String appointmentId) async {
    try {
      final doc = await _firestore.doc(FirestorePaths.appointment(appointmentId)).get();
      return doc.exists ? AppointmentModel.fromFirestore(doc) : null;
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to fetch appointment', code: e.code);
    }
  }

  Future<List<({String slot, int remaining})>> getAvailableSlots({
    required String hospitalId,
    required String departmentId,
    required String date,
  }) async {
    try {
      final result = await _functions.httpsCallable('getAvailableSlots').call<Map<String, dynamic>>({
        'hospitalId': hospitalId,
        'departmentId': departmentId,
        'date': date,
      });
      final slots = (result.data['slots'] as List).cast<Map<String, dynamic>>();
      return slots.map((s) => (slot: s['slot'] as String, remaining: s['remaining'] as int)).toList();
    } on FirebaseFunctionsException catch (e) {
      throw DataFailure(e.message ?? 'Failed to load available slots', code: e.code);
    }
  }

  Stream<List<AppointmentModel>> watchPatientAppointments(String patientId) {
    return _firestore
        .collection(FirestorePaths.appointments)
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snap) {
      final appts = snap.docs.map(AppointmentModel.fromFirestore).toList();
      appts.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate)); // descending
      return appts;
    });
  }

  /// Client-side aggregation over today's appointments for a hospital —
  /// small dataset (one hospital, one day), no need for a separate
  /// server-side count query.
  Stream<Map<String, int>> watchTodaysStatsForHospital({required String hospitalId, required String date}) {
    return watchTodaysAppointmentsForHospital(hospitalId: hospitalId, date: date).map((appts) {
      final counts = <String, int>{
        'booked': 0,
        'checked_in': 0,
        'completed': 0,
        'skipped': 0,
      };
      for (final a in appts) {
        counts[a.status] = (counts[a.status] ?? 0) + 1;
      }
      return counts;
    });
  }

  /// Everything this doctor has ever been assigned to — across all dates,
  /// not just today. No orderBy (avoids a composite-index requirement,
  /// same lesson as elsewhere in this app); sorted client-side.
  Stream<List<AppointmentModel>> watchDoctorAppointmentHistory({
    required String doctorId,
    required String hospitalId,
  }) {
    return _firestore
        .collection(FirestorePaths.appointments)
        .where('doctorId', isEqualTo: doctorId)
        .where('hospitalId', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) {
      final appts = snap.docs.map(AppointmentModel.fromFirestore).toList();
      appts.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      return appts;
    });
  }

  Stream<List<AppointmentModel>> watchAppointmentsBookedBy({
    required String uid,
    required String hospitalId,
  }) {
    return _firestore
        .collection(FirestorePaths.appointments)
        .where('bookedBy', isEqualTo: uid)
        .where('hospitalId', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) {
      final appts = snap.docs.map(AppointmentModel.fromFirestore).toList();
      appts.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      return appts;
    });
  }

  Stream<List<AppointmentModel>> watchTodaysAppointments({
    required String hospitalId,
    required String departmentId,
    required String date,
  }) {
    return _firestore
        .collection(FirestorePaths.appointments)
        .where('hospitalId', isEqualTo: hospitalId)
        .where('departmentId', isEqualTo: departmentId)
        .where('scheduledDate', isEqualTo: date)
        .snapshots()
        .map((snap) => snap.docs.map(AppointmentModel.fromFirestore).toList());
  }

  Stream<List<AppointmentModel>> watchTodaysAppointmentsForHospital({
    required String hospitalId,
    required String date,
  }) {
    return _firestore
        .collection(FirestorePaths.appointments)
        .where('hospitalId', isEqualTo: hospitalId)
        .where('scheduledDate', isEqualTo: date)
        .snapshots()
        .map((snap) => snap.docs.map(AppointmentModel.fromFirestore).toList());
  }
}