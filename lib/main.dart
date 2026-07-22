import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_init.dart';
import 'firebase_options.dart';

/// Firebase emulator flags — still used by Firestore/Functions until those
/// features migrate. Auth no longer uses the Firebase Auth emulator.
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initSupabase();

  // Firebase remains for non-auth features (Firestore queues, callables, etc.)
  // until those migration steps complete. Auth is Supabase-only.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8070);
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
  }

  runApp(const ProviderScope(child: HospitalQueueApp()));
}
