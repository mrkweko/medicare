import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/failures.dart';

class HospitalModel {
  final String id;
  final String name;
  final String address;
  final String? contactInfo;
  final String skipPolicy; // 'end_of_queue' | 'after_current'

  const HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    this.contactInfo,
    this.skipPolicy = 'end_of_queue',
  });

  factory HospitalModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return HospitalModel(
      id: doc.id,
      name: data['name'] as String,
      address: data['address'] as String,
      contactInfo: data['contactInfo'] as String?,
      skipPolicy: data['skipPolicy'] as String? ?? 'end_of_queue',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'contactInfo': contactInfo,
    'skipPolicy': skipPolicy,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class HospitalRepository {
  HospitalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> createHospital({
    required String name,
    required String address,
    String? contactInfo,
  }) async {
    try {
      final docRef = _firestore.collection(FirestorePaths.hospitals).doc();
      final hospital = HospitalModel(id: docRef.id, name: name, address: address, contactInfo: contactInfo);
      await docRef.set(hospital.toMap());
      return docRef.id;
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to create hospital', code: e.code);
    }
  }

  Stream<List<HospitalModel>> watchHospitals() {
    return _firestore
        .collection(FirestorePaths.hospitals)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(HospitalModel.fromFirestore).toList());
  }

  Stream<HospitalModel?> watchHospital(String hospitalId) {
    return _firestore.doc(FirestorePaths.hospital(hospitalId)).snapshots().map(
          (doc) => doc.exists ? HospitalModel.fromFirestore(doc) : null,
    );
  }

  Future<void> updateSkipPolicy({required String hospitalId, required String skipPolicy}) async {
    try {
      await _firestore.doc(FirestorePaths.hospital(hospitalId)).update({'skipPolicy': skipPolicy});
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to update skip policy', code: e.code);
    }
  }
}