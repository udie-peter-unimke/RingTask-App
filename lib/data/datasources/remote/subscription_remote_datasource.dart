import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ringtask/entities/subscription_entities.dart';
import 'package:ringtask/utils/logger.dart';

/// Remote data source for managing subscription data in Firestore.
/// Delegates network-specific logic away from the repository.
class SubscriptionRemoteDataSource {
  final FirebaseFirestore _firestore;

  SubscriptionRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _usersCollection = 'users';

  /// Fetches the subscription status from the user's document in Firestore.
  Future<SubscriptionStatus?> getSubscriptionStatus(String uid) async {
    try {
      AppLogger.info('Fetching remote subscription status for user: $uid');
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      
      if (!doc.exists || doc.data() == null) {
        AppLogger.info('No remote subscription data found for user: $uid');
        return null;
      }

      return SubscriptionStatus.fromFirestore(doc.data()!);
    } catch (e) {
      AppLogger.error('Error fetching remote subscription status: $e');
      rethrow;
    }
  }

  /// Updates the user's subscription status in Firestore.
  Future<void> saveSubscriptionStatus(String uid, SubscriptionStatus status) async {
    try {
      AppLogger.info('Saving remote subscription status for user: $uid');
      await _firestore.collection(_usersCollection).doc(uid).set(
        status.toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      AppLogger.error('Error saving remote subscription status: $e');
      rethrow;
    }
  }
}
