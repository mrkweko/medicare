import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_init.dart';
import 'firebase_options.dart';

/// Firebase remains only for a few Cloud Functions callables (walk-in patient,
/// referral, follow-up) until Step 9 replaces them. Firestore is fully migrated.
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initSupabase();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (useEmulator) {
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
  }

  runApp(const ProviderScope(child: HospitalQueueApp()));
}
