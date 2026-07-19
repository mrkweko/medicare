import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

/// Raw Firebase auth state — null when signed out. role_guard.dart / the
/// router will check "signed in at all" first via this, then role via
/// currentUserProfileProvider below.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Live Firestore profile (role, hospitalId, displayName) for whoever is
/// currently signed in. This is what role_guard.dart should key off of,
/// since role/hospitalId live in the doc, not (necessarily, given your
/// manual-edit workflow) the token.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUserProfile(uid);
});

/// Handles sign-in/sign-up submission state (loading/error) so the screens
/// don't talk to AuthRepository directly.
class AuthFormController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).signIn(email: email, password: password);
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
    String? phoneNumber,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password, displayName: displayName);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> signOut() async => ref.read(authRepositoryProvider).signOut();
}

final authFormControllerProvider =
AsyncNotifierProvider<AuthFormController, void>(AuthFormController.new);