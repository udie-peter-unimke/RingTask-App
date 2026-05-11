// lib/data/datasources/remote/user_remote_datasource.dart - ✅ FIXED
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ringtask/data/models/user_model.dart';
import 'package:ringtask/utils/logger.dart';

abstract class UserRemoteDataSource {
  Future<void> createUser(UserModel user);
  Future<UserModel?> getUser(String userId);
  Future<void> updateUser(UserModel user);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final FirebaseFirestore _firestore;
  final String _collection = 'users';

  UserRemoteDataSourceImpl(this._firestore);

  @override
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.id).set(user.toMap()); // ✅ FIXED
      AppLogger.info('User created: ${user.id}');
    } catch (e, s) {
      AppLogger.error('Create user failed: $e', stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!); // ✅ FIXED
    } catch (e, s) {
      AppLogger.error('Get user failed: $e', stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.id).update(user.toMap()); // ✅ FIXED
      AppLogger.info('User updated: ${user.id}');
    } catch (e, s) {
      AppLogger.error('Update user failed: $e', stackTrace: s);
      rethrow;
    }
  }
}
