import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentModel {
  final String id;
  final String hospitalId;
  final String name;

  const DepartmentModel({required this.id, required this.hospitalId, required this.name});

  factory DepartmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DepartmentModel(id: doc.id, hospitalId: d['hospitalId'], name: d['name']);
  }

  Map<String, dynamic> toMap() => {'hospitalId': hospitalId, 'name': name, 'createdAt': FieldValue.serverTimestamp()};
}