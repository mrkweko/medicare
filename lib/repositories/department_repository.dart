import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/failures.dart';
import '../models/department_model.dart';

class DepartmentRepository {
  DepartmentRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<void> createDepartment({required String hospitalId, required String name}) async {
    try {
      await _firestore.collection(FirestorePaths.departments).add(
        DepartmentModel(id: '', hospitalId: hospitalId, name: name).toMap(),
      );
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to create department', code: e.code);
    }
  }

  Stream<List<DepartmentModel>> watchDepartments(String hospitalId) {
    return _firestore
        .collection(FirestorePaths.departments)
        .where('hospitalId', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) => snap.docs.map(DepartmentModel.fromFirestore).toList());
  }
}