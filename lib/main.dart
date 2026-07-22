import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

/// Top-level function required by firebase_messaging — this runs in a
/// separate isolate when a push arrives while the app is fully terminated
/// or backgrounded, so it can't be a closure or instance method. Kept
/// minimal on purpose: the OS already shows the system notification for
/// data+notification payloads automatically in this state, this handler
/// exists mainly so FCM doesn't log a warning about a missing one.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8070);
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Foreground messages need explicit handling — FCM does NOT show a
  // system notification automatically while the app is in the foreground,
  // by design (the assumption is the app itself will surface it in-UI).
  // Since this app already writes a Firestore `notifications` doc for
  // every push sent (see queueNotifications.js), the in-app notification
  // screen/badge already reflects it live — a foreground banner would be
  // redundant on top of that, so deliberately not adding one here.
  FirebaseMessaging.onMessage.listen((message) {});

  runApp(const ProviderScope(child: HospitalQueueApp()));
}