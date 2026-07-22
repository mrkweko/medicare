import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/fcm_repository.dart';

import 'dart:async';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final fcmRepositoryProvider = Provider<FcmRepository>((ref) => FcmRepository());

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUserProfile(uid);
});

class AuthFormController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).signIn(email: email, password: password);
      // Fire-and-forget — permission dialog/token fetch shouldn't block
      // sign-in from completing, and a denial here isn't a sign-in failure.
      unawaited(ref.read(fcmRepositoryProvider).requestPermissionAndRegister(user.uid));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password, displayName: displayName, phoneNumber: phoneNumber);
      unawaited(ref.read(fcmRepositoryProvider).requestPermissionAndRegister(user.uid));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> signOut() async => ref.read(authRepositoryProvider).signOut();
}

final authFormControllerProvider = AsyncNotifierProvider<AuthFormController, void>(AuthFormController.new);