import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment_model.dart';
import '../models/department_model.dart';
import '../models/doctor_model.dart';
import '../models/user_model.dart';

/// Platform-wide, unscoped queries — only safe to call as super_admin.
/// isSuperAdmin() in firestore.rules is provable without depending on any
/// document field, which is what allows these list queries to pass at
/// all; every other role's equivalent queries must be scoped (e.g. by
/// hospitalId) or Firestore rejects the whole list request outright.
class SuperAdminRepository {
  SuperAdminRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Stream<List<UserModel>> watchAllUsers() {
    return _firestore.collection('users').snapshots().map(
          (snap) => snap.docs.map(UserModel.fromFirestore).toList(),
    );
  }

  Stream<List<DepartmentModel>> watchAllDepartments() {
    return _firestore.collection('departments').snapshots().map(
          (snap) => snap.docs.map(DepartmentModel.fromFirestore).toList(),
    );
  }

  Stream<List<DoctorModel>> watchAllDoctors() {
    return _firestore.collection('doctors').snapshots().map(
          (snap) => snap.docs.map(DoctorModel.fromFirestore).toList(),
    );
  }

  Stream<List<AppointmentModel>> watchAllAppointmentsForDate(String date) {
    return _firestore
        .collection('appointments')
        .where('scheduledDate', isEqualTo: date)
        .snapshots()
        .map((snap) => snap.docs.map(AppointmentModel.fromFirestore).toList());
  }
}