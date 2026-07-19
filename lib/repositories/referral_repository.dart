import 'package:cloud_functions/cloud_functions.dart';

import '../core/errors/failures.dart';

class ReferralRepository {
  ReferralRepository({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseFunctions _functions;

  Future<({String appointmentId, int tokenNumber, String visitId})> createReferral({
    required String originAppointmentId,
    required String targetDepartmentId,
  }) async {
    try {
      final result = await _functions.httpsCallable('createReferral').call<Map<String, dynamic>>({
        'originAppointmentId': originAppointmentId,
        'targetDepartmentId': targetDepartmentId,
      });
      return (
      appointmentId: result.data['appointmentId'] as String,
      tokenNumber: result.data['tokenNumber'] as int,
      visitId: result.data['visitId'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      throw DataFailure(e.message ?? 'Failed to create referral', code: e.code);
    }
  }

  Future<({String appointmentId, String scheduledDate, int tokenNumber})> createFollowUp({
    required String originAppointmentId,
    required int daysFromNow,
  }) async {
    try {
      final result = await _functions.httpsCallable('createFollowUpAppointment').call<Map<String, dynamic>>({
        'originAppointmentId': originAppointmentId,
        'daysFromNow': daysFromNow,
      });
      return (
      appointmentId: result.data['appointmentId'] as String,
      scheduledDate: result.data['scheduledDate'] as String,
      tokenNumber: result.data['tokenNumber'] as int,
      );
    } on FirebaseFunctionsException catch (e) {
      throw DataFailure(e.message ?? 'Failed to schedule follow-up', code: e.code);
    }
  }
}