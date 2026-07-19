import 'package:cloud_firestore/cloud_firestore.dart';

const _priorityRanks = {'critical': 0, 'urgent': 1, 'normal': 2};

class QueueEntryModel {
  final String id;
  final String appointmentId;
  final String patientId;
  final String doctorId;
  final int tokenNumber;
  final DateTime? checkedInAt;
  final String priority;
  final String status;
  final String lastNotifiedThreshold;

  const QueueEntryModel({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.tokenNumber,
    this.checkedInAt,
    required this.priority,
    required this.status,
    this.lastNotifiedThreshold = 'none',
  });

  factory QueueEntryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return QueueEntryModel(
      id: doc.id,
      appointmentId: d['appointmentId'],
      patientId: d['patientId'],
      doctorId: d['doctorId'] ?? '',
      tokenNumber: d['tokenNumber'],
      checkedInAt: (d['checkedInAt'] as Timestamp?)?.toDate(),
      priority: d['priority'] ?? 'normal',
      status: d['status'] ?? 'waiting',
      lastNotifiedThreshold: d['lastNotifiedThreshold'] ?? 'none',
    );
  }

  Map<String, dynamic> toMap() => {
    'appointmentId': appointmentId,
    'patientId': patientId,
    'doctorId': doctorId,
    'tokenNumber': tokenNumber,
    'checkedInAt': FieldValue.serverTimestamp(),
    'priority': priority,
    'priorityRank': _priorityRanks[priority] ?? 2,
    'status': status,
    'lastNotifiedThreshold': 'none', // trigger owns this field from here on
  };
}