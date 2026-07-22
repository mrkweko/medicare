import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment_model.dart';
import '../models/department_model.dart';
import '../models/doctor_model.dart';
import '../models/user_model.dart';
import 'department_repository.dart';
import 'doctor_repository.dart';

/// Platform-wide, unscoped queries — only safe to call as super_admin.
/// Departments + doctors are on Supabase; users/appointments remain on
/// Firestore until their migration steps.
class SuperAdminRepository {
  SuperAdminRepository({
    FirebaseFirestore? firestore,
    DepartmentRepository? departmentRepository,
    DoctorRepository? doctorRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _departmentRepository = departmentRepository ?? DepartmentRepository(),
        _doctorRepository = doctorRepository ?? DoctorRepository();

  final FirebaseFirestore _firestore;
  final DepartmentRepository _departmentRepository;
  final DoctorRepository _doctorRepository;

  Stream<List<UserModel>> watchAllUsers() {
    return _firestore.collection('users').snapshots().map(
          (snap) => snap.docs.map(UserModel.fromFirestore).toList(),
    );
  }

  Stream<List<DepartmentModel>> watchAllDepartments() {
    return _departmentRepository.watchAllDepartments();
  }

  Stream<List<DoctorModel>> watchAllDoctors() {
    return _doctorRepository.watchAllDoctors();
  }

  Stream<List<AppointmentModel>> watchAllAppointmentsForDate(String date) {
    return _firestore
        .collection('appointments')
        .where('scheduledDate', isEqualTo: date)
        .snapshots()
        .map((snap) => snap.docs.map(AppointmentModel.fromFirestore).toList());
  }
}
