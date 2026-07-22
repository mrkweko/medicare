import 'package:cloud_firestore/cloud_firestore.dart';

const _priorityRanks = {'critical': 0, 'urgent': 1, 'normal': 2};

class QueueEntryModel {
  final String id;
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String? patientPhoneNumber;
  final String doctorId;
  final int tokenNumber;
  final DateTime? checkedInAt;
  final DateTime? consultationStartedAt;
  final DateTime? warnedAt;
  final DateTime? graceDeadline;
  final String priority;
  final String status;
  final String lastNotifiedThreshold;
  final int? patientsAhead;

  const QueueEntryModel({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    this.patientPhoneNumber,
    required this.doctorId,
    required this.tokenNumber,
    this.checkedInAt,
    this.consultationStartedAt,
    this.warnedAt,
    this.graceDeadline,
    required this.priority,
    required this.status,
    this.lastNotifiedThreshold = 'none',
    this.patientsAhead,
  });

  factory QueueEntryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return QueueEntryModel(
      id: doc.id,
      appointmentId: d['appointmentId'],
      patientId: d['patientId'],
      patientName: d['patientName'] ?? 'Unknown',
      patientPhoneNumber: d['patientPhoneNumber'],
      doctorId: d['doctorId'] ?? '',
      tokenNumber: d['tokenNumber'],
      checkedInAt: (d['checkedInAt'] as Timestamp?)?.toDate(),
      consultationStartedAt: (d['consultationStartedAt'] as Timestamp?)?.toDate(),
      warnedAt: (d['warnedAt'] as Timestamp?)?.toDate(),
      graceDeadline: (d['graceDeadline'] as Timestamp?)?.toDate(),
      priority: d['priority'] ?? 'normal',
      status: d['status'] ?? 'waiting',
      lastNotifiedThreshold: d['lastNotifiedThreshold'] ?? 'none',
      patientsAhead: (d['patientsAhead'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'appointmentId': appointmentId,
    'patientId': patientId,
    'patientName': patientName,
    'patientPhoneNumber': patientPhoneNumber,
    'doctorId': doctorId,
    'tokenNumber': tokenNumber,
    'checkedInAt': FieldValue.serverTimestamp(),
    'priority': priority,
    'priorityRank': _priorityRanks[priority] ?? 2,
    'status': status,
    'lastNotifiedThreshold': 'none',
    'patientsAhead': null,
  };
}