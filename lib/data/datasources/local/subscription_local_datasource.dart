import 'package:ringtask/data/datasources/local/cache_manager.dart';
import 'package:ringtask/entities/subscription_entities.dart';
import 'package:ringtask/utils/logger.dart';

/// Local data source for persisting subscription status.
/// This allows the app to check premium status instantly at startup
/// even without a network connection.
class SubscriptionLocalDataSource {
  final CacheManager _cacheManager;

  SubscriptionLocalDataSource({required CacheManager cacheManager})
      : _cacheManager = cacheManager;

  /// Saves the subscription status to local storage.
  Future<void> saveSubscriptionStatus(SubscriptionStatus status) async {
    try {
      final Map<String, dynamic> data = status.toFirestore();
      
      // Convert DateTime to ISO8601 string for local JSON storage
      // since SharedPreferences doesn't support Timestamp.
      if (status.expiryDate != null) {
        data['subscriptionExpiryDate'] = status.expiryDate!.toIso8601String();
      }

      await _cacheManager.cacheSubscriptionStatus(data);
    } catch (e) {
      AppLogger.error('Error saving local subscription status: $e');
    }
  }

  /// Retrieves the subscription status from local storage.
  Future<SubscriptionStatus?> getSubscriptionStatus() async {
    try {
      final data = await _cacheManager.getCachedSubscriptionStatus();
      if (data == null) return null;

      // Convert ISO8601 string back to DateTime if present
      final dynamic rawExpiry = data['subscriptionExpiryDate'];
      DateTime? expiry;
      if (rawExpiry is String) {
        expiry = DateTime.tryParse(rawExpiry);
      }

      return SubscriptionStatus(
        tier: data['subscriptionTier'] == 'premium'
            ? SubscriptionTier.premium
            : SubscriptionTier.free,
        activeProductId: data['productId'] as String?,
        expiryDate: expiry,
        isLifetime: data['isLifetime'] as bool? ?? false,
        purchaseToken: data['purchaseToken'] as String?,
      );
    } catch (e) {
      AppLogger.error('Error retrieving local subscription status: $e');
      return null;
    }
  }

  /// Clears the local subscription cache.
  Future<void> clearCache() async {
    await _cacheManager.clearCachedSubscriptionStatus();
  }
}
