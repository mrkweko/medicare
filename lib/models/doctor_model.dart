import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorModel {
  final String uid;
  final String displayName;
  final String hospitalId;
  final String departmentId;
  final int avgConsultationMinutes;

  const DoctorModel({
    required this.uid,
    required this.displayName,
    required this.hospitalId,
    required this.departmentId,
    required this.avgConsultationMinutes,
  });

  factory DoctorModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DoctorModel(
      uid: doc.id,
      displayName: d['displayName'] ?? 'Unnamed',
      hospitalId: d['hospitalId'],
      departmentId: d['departmentId'],
      avgConsultationMinutes: d['avgConsultationMinutes'] ?? 15,
    );
  }
}