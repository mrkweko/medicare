import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String patientId;
  final String hospitalId;
  final String departmentId;
  final String? doctorId;
  final String scheduledDate;
  final String? scheduledTimeSlot;
  final int tokenNumber;
  final String status;
  final String? visitId;
  final bool isRecurring;
  final String? recurringParentId;
  final String bookedBy;

  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.hospitalId,
    required this.departmentId,
    required this.doctorId,
    required this.scheduledDate,
    this.scheduledTimeSlot,
    required this.tokenNumber,
    required this.status,
    this.visitId,
    required this.isRecurring,
    this.recurringParentId,
    required this.bookedBy,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AppointmentModel(
      id: doc.id,
      patientId: d['patientId'],
      hospitalId: d['hospitalId'],
      departmentId: d['departmentId'],
      doctorId: d['doctorId'],
      scheduledDate: d['scheduledDate'],
      scheduledTimeSlot: d['scheduledTimeSlot'],
      tokenNumber: d['tokenNumber'],
      status: d['status'],
      visitId: d['visitId'],
      isRecurring: d['isRecurring'] ?? false,
      recurringParentId: d['recurringParentId'],
      bookedBy: d['bookedBy'],
    );
  }
}