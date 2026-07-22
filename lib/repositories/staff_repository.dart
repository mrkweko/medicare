import 'package:cloud_functions/cloud_functions.dart';

import '../core/errors/failures.dart';

class StaffRepository {
  StaffRepository({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseFunctions _functions;

  Future<String> createStaffAccount({
    required String email,
    required String password,
    required String role,
    String? displayName,
    String? hospitalId,
    String? departmentId,
    String? roomNumber,
  }) async {
    try {
      final callable = _functions.httpsCallable('createStaffAccount');
      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
        'password': password,
        'displayName': displayName,
        'role': role,
        'hospitalId': hospitalId,
        'departmentId': departmentId,
        'roomNumber': roomNumber,
      });
      return result.data['uid'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw AuthFailure(e.message ?? 'Failed to create staff account', code: e.code);
    }
  }
}