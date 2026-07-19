import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

// Run with --dart-define=USE_EMULATOR=true (or false) to control this
// explicitly. Defaults to true so existing local dev workflows (no flag
// passed) keep working exactly as before — this is additive, not a
// behavior change for anyone not yet thinking about cutover.
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

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

  runApp(const ProviderScope(child: HospitalQueueApp()));
}