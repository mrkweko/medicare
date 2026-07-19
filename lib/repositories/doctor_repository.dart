import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/failures.dart';
import '../models/doctor_model.dart';

class DoctorRepository {
  DoctorRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Stream<List<DoctorModel>> watchDoctors({required String hospitalId, required String departmentId}) {
    return _firestore
        .collection('doctors')
        .where('hospitalId', isEqualTo: hospitalId)
        .where('departmentId', isEqualTo: departmentId)
        .snapshots()
        .map((snap) => snap.docs.map(DoctorModel.fromFirestore).toList());
  }

  /// All doctors in a hospital, regardless of department — for the
  /// hospital_admin's reassignment screen.
  Stream<List<DoctorModel>> watchAllDoctorsForHospital(String hospitalId) {
    return _firestore
        .collection('doctors')
        .where('hospitalId', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) => snap.docs.map(DoctorModel.fromFirestore).toList());
  }

  Stream<DoctorModel?> watchMyDoctorProfile(String uid) {
    return _firestore.collection('doctors').doc(uid).snapshots().map(
          (doc) => doc.exists ? DoctorModel.fromFirestore(doc) : null,
    );
  }

  Future<void> reassignDepartment({required String doctorId, required String newDepartmentId}) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).update({'departmentId': newDepartmentId});
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to reassign department', code: e.code);
    }
  }
}