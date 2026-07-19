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