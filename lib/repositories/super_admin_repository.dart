import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment_model.dart';
import '../models/department_model.dart';
import '../models/doctor_model.dart';
import '../models/user_model.dart';
import 'appointment_repository.dart';
import 'department_repository.dart';
import 'doctor_repository.dart';

/// Platform-wide, unscoped queries — only safe to call as super_admin.
/// Hospitals/departments/doctors/appointments are on Supabase; the users
/// list remains on Firestore until profiles listing is migrated.
class SuperAdminRepository {
  SuperAdminRepository({
    FirebaseFirestore? firestore,
    DepartmentRepository? departmentRepository,
    DoctorRepository? doctorRepository,
    AppointmentRepository? appointmentRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _departmentRepository = departmentRepository ?? DepartmentRepository(),
        _doctorRepository = doctorRepository ?? DoctorRepository(),
        _appointmentRepository = appointmentRepository ?? AppointmentRepository();

  final FirebaseFirestore _firestore;
  final DepartmentRepository _departmentRepository;
  final DoctorRepository _doctorRepository;
  final AppointmentRepository _appointmentRepository;

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
    return _appointmentRepository.watchAllAppointmentsForDate(date);
  }
}
