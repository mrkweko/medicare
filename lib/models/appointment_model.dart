import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? patientPhoneNumber;
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
  final DateTime? checkedInAt;
  final String source;

  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientPhoneNumber,
    required this.hospitalId,
    required this.departmentId,
    this.doctorId,
    required this.scheduledDate,
    this.scheduledTimeSlot,
    required this.tokenNumber,
    required this.status,
    this.visitId,
    required this.isRecurring,
    this.recurringParentId,
    required this.bookedBy,
    this.checkedInAt,
    this.source = 'patient_booking',
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AppointmentModel(
      id: doc.id,
      patientId: d['patientId'],
      patientName: d['patientName'] ?? 'Unknown',
      patientPhoneNumber: d['patientPhoneNumber'],
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
      checkedInAt: (d['checkedInAt'] as Timestamp?)?.toDate(),
      source: d['source'] ?? 'patient_booking', // fallback for appointments created before this field existed
    );
  }
}