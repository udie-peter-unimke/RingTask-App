// lib/services/entitlement/entitlement_service.dart

import 'package:ringtask/entities/subscription_entities.dart';
import 'package:ringtask/repositories/subscription/subscription_repository.dart';
import 'package:ringtask/utils/logger.dart';

import 'package:ringtask/data/models/loop_model.dart';

/// Central service for checking feature access based on subscription tier.
class EntitlementService {
  final SubscriptionRepository _subscriptionRepository;
  
  SubscriptionStatus _currentStatus = SubscriptionStatus.defaultFree;

  EntitlementService({required SubscriptionRepository subscriptionRepository})
      : _subscriptionRepository = subscriptionRepository;

  /// Returns the current cached subscription status.
  SubscriptionStatus get currentStatus => _currentStatus;

  /// Initializes the entitlement status for a user.
  Future<void> initialize(String uid) async {
    try {
      _currentStatus = await _subscriptionRepository.getSubscriptionStatus(uid);
      AppLogger.info('EntitlementService initialized for $uid: $_currentStatus');
    } catch (e) {
      AppLogger.error('Failed to initialize EntitlementService: $e');
    }
  }

  /// Updates the status manually (e.g. after a purchase).
  void updateStatus(SubscriptionStatus status) {
    _currentStatus = status;
    AppLogger.info('EntitlementService status updated: $_currentStatus');
  }

  // ─── Feature Access Checks ──────────────────────────────────────────────────

  /// Whether the user has a Premium tier.
  bool get isPremium => _currentStatus.isActive;

  /// Free users have a limit of 10 virtual call reminders per month.
  /// (Implementation note: This currently checks just the tier. 
  ///  Tracking the monthly count would require a Firestore counter).
  bool get canUseVirtualCallReminders => isPremium;

  /// Unlimited for Premium, Limited for Free.
  bool get canUseUnlimitedVoiceScheduling => isPremium;

  /// Free: Daily only. Premium: Daily, Weekly, Monthly.
  bool canUseRecurrenceType(RecurrenceType type) {
    if (isPremium) return true;
    return type == RecurrenceType.daily || type == RecurrenceType.oneTime;
  }

  /// Advanced TTS is a premium feature.
  bool get hasAdvancedTts => isPremium;

  /// Priority support is for premium users.
  bool get hasPrioritySupport => isPremium;
}
