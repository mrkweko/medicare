import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

import 'appointment_repository.dart';
import 'queue_repository.dart';

class WalkInBookingHelper {
  WalkInBookingHelper({
    required AppointmentRepository appointmentRepository,
    required QueueRepository queueRepository,
    FirebaseFunctions? functions,
  })  : _appointmentRepository = appointmentRepository,
        _queueRepository = queueRepository,
        _functions = functions ?? FirebaseFunctions.instance;

  final AppointmentRepository _appointmentRepository;
  final QueueRepository _queueRepository;
  final FirebaseFunctions _functions;

  /// Shared by walkin_booking_screen.dart (always priority: 'normal') and
  /// Priority Check-In's walk-in-emergency tab (priority: 'critical'/'urgent')
  /// — previously duplicated verbatim in both, now one implementation.
  Future<int> bookAndCheckIn({
    required String displayName,
    String? phoneNumber,
    required String hospitalId,
    required String departmentId,
    required String priority,
  }) async {
    final createPatientResult = await _functions.httpsCallable('createWalkInPatient').call<Map<String, dynamic>>({
      'displayName': displayName,
      'phoneNumber': phoneNumber,
    });
    final patientId = createPatientResult.data['uid'] as String;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final appointmentResult = await _appointmentRepository.createAppointment(
      patientId: patientId,
      hospitalId: hospitalId,
      departmentId: departmentId,
      scheduledDate: today,
    );

    await _queueRepository.checkIn(
      patientName: displayName,
      patientPhoneNumber: phoneNumber,
      appointmentId: appointmentResult.appointmentId,
      patientId: patientId,
      tokenNumber: appointmentResult.tokenNumber,
      hospitalId: hospitalId,
      date: today,
      departmentId: departmentId,
      priority: priority,
    );

    return appointmentResult.tokenNumber;
  }
}