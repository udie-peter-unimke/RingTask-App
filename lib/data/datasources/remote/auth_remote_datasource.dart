// lib/data/datasources/remote/auth_remote_datasource.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ringtask/utils/logger.dart';

/// AUTH REMOTE DATA SOURCE CONTRACT
abstract class AuthRemoteDataSource {
  Future<User?> signUpWithEmail(String email, String password);
  Future<User?> loginWithEmail(String email, String password);
  Future<User?> loginWithGoogle();
  Future<void> signOut();
  User? getCurrentUser();
  Future<void> resetPassword(String email);
  Future<void> updateProfile(String displayName, String photoUrl);
  Future<void> changePassword(String currentPassword, String newPassword);
}

/// AUTH REMOTE DATA SOURCE IMPLEMENTATION
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleInitialized = false;

  AuthRemoteDataSourceImpl(this._auth) {
    // Kick off initialization immediately so it's ready when the user clicks sign-in.
    _ensureGoogleInitialized();
  }

  Future<void> _ensureGoogleInitialized() async {
    if (!_isGoogleInitialized) {
      try {
        await _googleSignIn.initialize(
          // FIX: Swapped to the correct client_type: 3 (Web Application) Client ID
          serverClientId: '909170843494-ls8vio52f9nm4r26rc01uor70c1gersc.apps.googleusercontent.com',
        );
        _isGoogleInitialized = true;
        AppLogger.info('Google Sign-In initialized');
      } catch (e) {
        AppLogger.error('Google Sign-In initialization failed: $e');
      }
    }
  }

  /// -------------------------------
  /// Email & Password Authentication
  /// -------------------------------
  @override
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('User signed up successfully: ${result.user?.uid}');
      return result.user;
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Email SignUp failed: ${e.code} - ${e.message}', stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('User logged in successfully: ${result.user?.uid}');
      return result.user;
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Email Login failed: ${e.code} - ${e.message}', stackTrace: s);
      rethrow;
    }
  }

  /// -------------------------------
  /// Google Sign-In Authentication
  /// -------------------------------
  @override
  Future<User?> loginWithGoogle() async {
    try {
      AppLogger.info('Starting Google Sign-In...');

      await _ensureGoogleInitialized();

      // v7+: authenticate() throws GoogleSignInException(code: canceled)
      // instead of returning null when the user cancels.
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      AppLogger.info('Google account selected: ${googleUser.email}');

      // v7+: authentication is a synchronous getter now, no await needed.
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        AppLogger.error('Failed to obtain Google ID token');
        await _googleSignIn.signOut();
        throw Exception('Google authentication failed: no ID token');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      AppLogger.info('Google Sign-In successful: ${userCredential.user?.uid}');
      return userCredential.user;

    } on GoogleSignInException catch (e, s) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        AppLogger.warning('Google Sign-In canceled by user');
        return null;
      }
      AppLogger.error('Google Sign-In failed: ${e.code} - ${e.description}', stackTrace: s);
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      rethrow;
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Firebase Google Auth failed: ${e.code} - ${e.message}', stackTrace: s);
      await _googleSignIn.signOut();
      rethrow;
    } catch (e, s) {
      AppLogger.error('Google Sign-In failed: $e', stackTrace: s);
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      rethrow;
    }
  }

  /// -------------------------------
  /// Sign Out
  /// -------------------------------
  @override
  Future<void> signOut() async {
    try {
      AppLogger.info('Signing out...');
      await _googleSignIn.signOut();
      await _auth.signOut();
      AppLogger.info('Sign-out successful');
    } catch (e, s) {
      AppLogger.error('SignOut failed: $e', stackTrace: s);
      rethrow;
    }
  }

  @override
  User? getCurrentUser() => _auth.currentUser;

  /// -------------------------------
  /// Password Reset
  /// -------------------------------
  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      AppLogger.info('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Password reset failed: ${e.code} - ${e.message}', stackTrace: s);
      rethrow;
    }
  }

  /// -------------------------------
  /// Profile Update
  /// -------------------------------
  @override
  Future<void> updateProfile(String displayName, String photoUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'no-user', message: 'No user is currently signed in');
      }

      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoUrl);
      await user.reload();
      AppLogger.info('Profile updated successfully for user: ${user.uid}');
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Profile update failed: ${e.code} - ${e.message}', stackTrace: s);
      rethrow;
    }
  }

  /// -------------------------------
  /// Change Password
  /// -------------------------------
  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) {
        throw FirebaseAuthException(code: 'no-user', message: 'No user is currently signed in');
      }

      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      AppLogger.info('Password changed successfully for user: ${user.uid}');
    } on FirebaseAuthException catch (e, s) {
      AppLogger.error('Password change failed: ${e.code} - ${e.message}', stackTrace: s);
      rethrow;
    }
  }
}