import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type;
  final String message;
  final bool read;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    required this.read,
    this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return NotificationModel(
      id: doc.id,
      type: d['type'] ?? 'info',
      message: d['message'] ?? '',
      read: d['read'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}