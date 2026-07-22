import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmRepository {
  FcmRepository({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  Future<void> requestPermissionAndRegister(String userId) async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return; // user declined — app still works via in-app notifications, just no push
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(userId, token);
    }

    // Tokens rotate (app reinstall, data clear, etc.) — keep it current.
    _messaging.onTokenRefresh.listen((newToken) => _saveToken(userId, newToken));
  }

  Future<void> _saveToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({'fcmToken': token});
  }
}