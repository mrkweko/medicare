import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/failures.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  /// Self-service signup always creates a `patient`. This is the ONLY role
  /// the app itself can create directly — hospital_admin, receptionist, and
  /// doctor accounts are created by an admin later in Phase 1, never here.
  Future<UserModel> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    try {
      final credential =
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;

      if (displayName != null && displayName.isNotEmpty) {
        await credential.user!.updateDisplayName(displayName);
      }

      final userModel = UserModel(
        uid: uid,
        email: email,
        displayName: displayName,
        phoneNumber: phoneNumber,
        role: AppRole.patient,
        hospitalId: null,
      );

      await _firestore.doc(FirestorePaths.user(uid)).set(userModel.toMap());

      // onUserDocWritten fires asynchronously after this write — don't
      // return until the claim has actually landed on the token, or
      // anything the caller does immediately after signup (like booking)
      // will hit a stale token with no role claim yet.
      await _waitForClaimsSync(expectedRole: 'patient');

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Sign up failed', code: e.code);
    } on FirebaseException catch (e) {
      throw DataFailure('Account created but profile setup failed: ${e.message}', code: e.code);
    }
  }

  /// Polls with backoff for the custom claim to actually appear on a fresh
  /// ID token, rather than assuming a single refresh is enough — the
  /// setCustomClaims trigger's completion time isn't guaranteed to beat a
  /// naive one-shot refresh, especially on a cold function start.
  Future<void> _waitForClaimsSync({required String expectedRole, int maxAttempts = 6}) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      final tokenResult = await _auth.currentUser?.getIdTokenResult(true);
      if (tokenResult?.claims?['role'] == expectedRole) return;
    }
    // Gave up waiting — not fatal, the trigger will still complete on its
    // own eventually, but the very next privileged action might still hit
    // a stale token. ensureFreshToken() below is the second safety net.
  }

  /// Defensive refresh to call immediately before any action that depends
  /// on custom claims (booking, check-in, etc.) — cheap insurance against
  /// the same staleness class of bug showing up in a new place later.
  Future<void> ensureFreshToken() => refreshIdToken();

  Future<UserModel> signIn({required String email, required String password}) async {
    try {
      final credential =
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final profile = await fetchUserProfile(credential.user!.uid);
      if (profile == null) {
        throw const AuthFailure(
          'Signed in but no matching users/{uid} profile doc was found.',
          code: 'missing-profile',
        );
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Sign in failed', code: e.code);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserModel?> fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.doc(FirestorePaths.user(uid)).get();
      return doc.exists ? UserModel.fromFirestore(doc) : null;
    } on FirebaseException catch (e) {
      throw DataFailure(e.message ?? 'Failed to fetch user profile', code: e.code);
    }
  }

  /// Live profile stream — use this, not a one-off fetch, anywhere the UI
  /// needs to react to role/hospitalId changes made by an admin (including
  /// your manual-edit-in-Firestore-console workflow).
  Stream<UserModel?> watchUserProfile(String uid) {
    return _firestore.doc(FirestorePaths.user(uid)).snapshots().map(
          (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
    );
  }

  /// Forces a fresh ID token (and therefore fresh custom claims) from the
  /// server. Since you're editing role/hospitalId by hand in Firestore
  /// rather than via a synced trigger, the *rules* won't see that change
  /// until this is called and the user re-authenticates — the Firestore
  /// doc updating alone does not touch the token's claims. Worth calling
  /// this from a manual "Refresh my permissions" action in a dev/admin
  /// screen until the sync trigger (if you build it later) exists.
  Future<void> refreshIdToken() async {
    await _auth.currentUser?.getIdToken(true);
  }
}