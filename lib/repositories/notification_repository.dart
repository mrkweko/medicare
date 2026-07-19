import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  /// No orderBy in the query itself — same lesson as watchPatientAppointments
  /// earlier: equality filter + orderBy on a different field needs a
  /// composite index, so sort client-side instead.
  Stream<List<NotificationModel>> watchMyNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(NotificationModel.fromFirestore).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Future<void> markAsRead(String notificationId) {
    return _firestore.collection('notifications').doc(notificationId).update({'read': true});
  }
}