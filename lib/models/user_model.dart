import 'package:cloud_firestore/cloud_firestore.dart';

enum AppRole {
  superAdmin,
  hospitalAdmin,
  receptionist,
  doctor,
  patient;

  static AppRole fromString(String value) {
    switch (value) {
      case 'super_admin':
        return AppRole.superAdmin;
      case 'hospital_admin':
        return AppRole.hospitalAdmin;
      case 'receptionist':
        return AppRole.receptionist;
      case 'doctor':
        return AppRole.doctor;
      case 'patient':
        return AppRole.patient;
      default:
        throw ArgumentError('Unknown role string: $value');
    }
  }

  String toFirestoreString() {
    switch (this) {
      case AppRole.superAdmin:
        return 'super_admin';
      case AppRole.hospitalAdmin:
        return 'hospital_admin';
      case AppRole.receptionist:
        return 'receptionist';
      case AppRole.doctor:
        return 'doctor';
      case AppRole.patient:
        return 'patient';
    }
  }
}

class UserModel {
  final String uid;
  final String? email; // null for walk-in patients created without one (createWalkInPatient)
  final String? displayName;
  final String? phoneNumber;
  final AppRole role;
  final String? hospitalId;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    required this.role,
    this.hospitalId,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('UserModel.fromFirestore: doc ${doc.id} has no data');
    }
    return UserModel(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      role: AppRole.fromString(data['role'] as String),
      hospitalId: data['hospitalId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role.toFirestoreString(),
      'hospitalId': hospitalId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({String? displayName, String? phoneNumber, AppRole? role, String? hospitalId}) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      hospitalId: hospitalId ?? this.hospitalId,
      createdAt: createdAt,
    );
  }
}