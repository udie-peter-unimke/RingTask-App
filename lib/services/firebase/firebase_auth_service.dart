import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ringtask/data/models/user_model.dart';
//import 'package:ringtask/services/firebase/firestore_service.dart';
import 'package:ringtask/utils/logger.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth;
 // final FirestoreService _firestoreService = FirestoreService();

  FirebaseAuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Google Sign-In
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Create a new instance with desired scopes if you need them.
      final googleSignIn = GoogleSignIn.instance;
        // scopes: ['email', 'profile'],

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Some providers may only return idToken on certain platforms.
      final String? idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        AppLogger.error('Google Sign-In: idToken is null or empty');
        return null;
      }

      final oauthCred = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(oauthCred);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      AppLogger.info('Google Sign-In successful: ${firebaseUser.email}');

      final userModel = await _createOrGetUserModel(firebaseUser);

      // Optional: persist user document if you have this method implemented
      // await _firestoreService.saveUser(userModel);

      return userModel;
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Firebase Auth error (Google): ${e.code}', error: e, stackTrace: s);
      return null;
    } catch (e, s) {
      AppLogger.error('Google Sign-In failed', error: e, stackTrace: s);
      return null;
    }
  }

  // Email/Password — add these if your AuthRepository calls them.
  Future<UserModel?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) return null;
      return _createOrGetUserModel(user);
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Firebase Auth error (signIn): ${e.code}', error: e, stackTrace: s);
      return null;
    }
  }

  Future<UserModel?> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (displayName != null && displayName.isNotEmpty) {
        await cred.user?.updateDisplayName(displayName);
      }
      final user = cred.user;
      if (user == null) return null;
      final model = await _createOrGetUserModel(user);

      // Optional: persist user document
      // await _firestoreService.saveUser(model);

      return model;
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Firebase Auth error (signUp): ${e.code}', error: e, stackTrace: s);
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      AppLogger.info('Password reset email sent to $email');
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Password reset failed: ${e.code}', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return _createOrGetUserModel(u);
  }

  Future<void> updateUserProfile({String? displayName, String? photoUrl}) async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      if (displayName != null) {
        await u.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await u.updatePhotoURL(photoUrl);
      }
      await u.reload();
      AppLogger.info('User profile updated');
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Update profile failed: ${e.code}', error: e, stackTrace: s);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      await u.updatePassword(newPassword);
      AppLogger.info('Password updated');
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Update password failed: ${e.code}', error: e, stackTrace: s);
    }
  }

  Future<void> reauthenticateUser(AuthCredential credential) async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      await u.reauthenticateWithCredential(credential);
      AppLogger.info('Reauthentication successful');
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Reauthentication failed: ${e.code}', error: e, stackTrace: s);
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out Firebase first
      await _auth.signOut();

      // Best-effort Google disconnect on mobile/web (skip on platforms where not applicable)
      try {
        final googleSignIn = GoogleSignIn.instance;
        // Only attempt if Google services are available
        if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
          await googleSignIn.signOut();
        }
      } catch (e) {
        // Ignored: not fatal if GoogleSignIn isn't configured for this platform
      }

      AppLogger.info('Signed out successfully');
    } catch (e, s) {
      AppLogger.error('Sign out failed', error: e, stackTrace: s);
    }
  }

  // Internal helper to map Firebase User to your UserModel
  Future<UserModel> _createOrGetUserModel(User firebaseUser) async {
    try {
      final model = UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      AppLogger.info('User model created: ${model.displayName}');
      return model;
    } catch (e, s) {
      AppLogger.error('Failed to create user model', error: e, stackTrace: s);
      return UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }
}
