// lib/repositories/auth_repository.dart - ✅ FIXED FOR GOOGLE SIGN-IN 7.2.0
import 'dart:async';
import 'package:ringtask/data/models/user_model.dart';
import 'package:ringtask/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ringtask/services/firebase/firestore_service.dart';
import 'package:ringtask/utils/logger.dart';
import 'package:ringtask/core/di/service_locator.dart'; // ✅ ADD THIS for getIt
//import 'package:firebase_auth/firebase_auth.dart';

abstract class IAuthRepository {
  Future<UserModel?> login(String email, String password);
  Future<UserModel?> signup(String email, String password, String displayName);
  Future<UserModel?> signInWithGoogle();
  Future<UserModel?> getCurrentUser();
  Future<bool> logout();
  Future<bool> resetPassword(String email);
  Future<bool> updateUserProfile(String displayName, String photoUrl);
  Future<bool> changePassword(String currentPassword, String newPassword);
  Future<bool> isUserLoggedIn();
}

class AuthRepository implements IAuthRepository {
  final AuthRemoteDataSource _authRemoteDataSource;
  final FirestoreService _firestoreService;

  // ✅ FIXED: Updated constructor parameter name to match
  AuthRepository({
    required AuthRemoteDataSource authRemoteDataSource, // ✅ Fixed parameter name
    FirestoreService? firestoreService,
  })  : _authRemoteDataSource = authRemoteDataSource,
        _firestoreService = firestoreService ?? getIt<FirestoreService>();

  @override
  Future<UserModel?> login(String email, String password) async {
    try {
      final user = await _authRemoteDataSource.loginWithEmail(email, password);
      if (user == null) return null;

      final data = await _firestoreService.getUserData(user.uid);
      return data != null ? UserModel.fromMap(data) : UserModel.fromFirebaseUser(user);
    } catch (e) {
      AppLogger.error('Login failed', error: e);
      rethrow;
    }
  }

  @override
  Future<UserModel?> signup(String email, String password, String displayName) async {
    try {
      // 1. Authenticate with Firebase Auth (Required first step)
      final user = await _authRemoteDataSource.signUpWithEmail(email, password);
      if (user == null) return null;

      final userModel = UserModel(
        id: user.uid,
        email: user.email ?? '',
        displayName: displayName,
        photoUrl: user.photoURL ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 2. Fire and forget the Firestore creation AND Auth Profile update.
      // This allows the UI to proceed immediately to the home screen.
      unawaited(_firestoreService.createUserData(userModel.id, userModel.toMap()));
      unawaited(_authRemoteDataSource.updateProfile(displayName, ''));
      
      AppLogger.info('User created in Auth, Firestore sync and Profile update started in background: ${user.uid}');
      return userModel;
    } catch (e) {
      AppLogger.error('Signup failed', error: e);
      rethrow;
    }
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    try {
      AppLogger.info('Signing in with Google');

      final user = await _authRemoteDataSource.loginWithGoogle();
      if (user == null) return null;

      // Check if it's a brand new user to avoid unnecessary Firestore read.
      // creationTime and lastSignInTime are very close (within seconds) for new users.
      final creationTime = user.metadata.creationTime;
      final lastSignInTime = user.metadata.lastSignInTime;
      final isNewUser = creationTime != null &&
          lastSignInTime != null &&
          lastSignInTime.difference(creationTime).inSeconds.abs() < 10;

      if (isNewUser) {
        AppLogger.info('New Google user detected via metadata; skipping Firestore read');
        final userModel = UserModel.fromFirebaseUser(user);
        unawaited(_firestoreService.createUserData(userModel.id, userModel.toMap()));
        return userModel;
      }

      // Existing user; check Firestore for supplemental data
      final existingData = await _firestoreService.getUserData(user.uid);

      if (existingData == null) {
        final userModel = UserModel.fromFirebaseUser(user);
        unawaited(_firestoreService.createUserData(userModel.id, userModel.toMap()));
        AppLogger.info('Google user record missing in Firestore; sync started: ${userModel.id}');
        return userModel;
      } else {
        AppLogger.info('Existing Google user logged in: ${user.uid}');
        return UserModel.fromMap(existingData);
      }
    } catch (e) {
      AppLogger.error('Google sign-in failed', error: e);
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _authRemoteDataSource.getCurrentUser();
      if (user == null) return null;

      final data = await _firestoreService.getUserData(user.uid);
      return data != null ? UserModel.fromMap(data) : UserModel.fromFirebaseUser(user);
    } catch (e) {
      AppLogger.error('Get current user failed', error: e);
      return null;
    }
  }

  @override
  Future<bool> logout() async {
    try {
      await _authRemoteDataSource.signOut();
      return true;
    } catch (e) {
      AppLogger.error('Logout failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> resetPassword(String email) async {
    try {
      // ✅ FIXED: Use public method instead of accessing private _auth
      await _authRemoteDataSource.resetPassword(email);
      return true;
    } catch (e) {
      AppLogger.error('Password reset failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> updateUserProfile(String displayName, String photoUrl) async {
    try {
      // ✅ FIXED: Use public method instead of accessing private _auth
      await _authRemoteDataSource.updateProfile(displayName, photoUrl);

      final user = await getCurrentUser();
      if (user != null) {
        final updatedData = user.toMap()
          ..['displayName'] = displayName
          ..['photoUrl'] = photoUrl
          ..['updatedAt'] = DateTime.now().toIso8601String();
        await _firestoreService.updateUserData(user.id, updatedData);
      }
      return true;
    } catch (e) {
      AppLogger.error('Profile update failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      // ✅ FIXED: Use public method instead of accessing private _auth
      await _authRemoteDataSource.changePassword(currentPassword, newPassword);
      return true;
    } catch (e) {
      AppLogger.error('Password change failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> isUserLoggedIn() async {
    return _authRemoteDataSource.getCurrentUser() != null;
  }
}