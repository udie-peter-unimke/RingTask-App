// lib/entities/subscription_entities.dart
//
// Single source of truth for product IDs, static plan metadata,
// and the SubscriptionStatus domain entity.

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Product IDs ─────────────────────────────────────────────────────────────
// Must match exactly what you register in Google Play Console.

// The subscription product ID containing multiple base plans
const String kProductIdPremiumSubscription = 'com.apexyron.ringtask.sub.premium';

// Base Plan IDs (used for matching in UI)
const String kBasePlanMonthly   = 'premium-monthly';
const String kBasePlanQuarterly = 'premium-quarterly';
const String kBasePlanYearly    = 'premium-yearly';

// Lifetime Unlock (Non-consumable)
const String kProductIdLifetime = 'com.apexyron.ringtask.unlock.lifetime_earlybird';

/// All product IDs to query from Play Billing.
const Set<String> kAllProductIds = {
  kProductIdPremiumSubscription,
  kProductIdLifetime,
};

// ─── Plan Config ──────────────────────────────────────────────────────────────
// Static display data shown before real prices arrive from Play Billing.

class PlanConfig {
  final String id; // Matches Base Plan ID or Lifetime Product ID
  final String title;
  final String tagline;

  /// Shown while real price from Play Billing is loading.
  final String fallbackPrice;

  /// Badge text, e.g. "Best Value", "⭐ Early Bird". Null = no badge.
  final String? badge;

  /// True for Lifetime (INAPP), false for recurring subscriptions (SUBS).
  final bool isOneTime;

  final List<String> features;

  const PlanConfig({
    required this.id,
    required this.title,
    required this.tagline,
    required this.fallbackPrice,
    this.badge,
    this.isOneTime = false,
    required this.features,
  });
}

/// Ordered list of plans displayed in [SubscriptionPage].
const List<PlanConfig> kSubscriptionPlans = [
  PlanConfig(
    id: kBasePlanMonthly,
    title: 'Premium Monthly',
    tagline: 'Full control, billed monthly',
    fallbackPrice: r'$0.62/month',
    features: [
      'Everything in Free',
      'Unlimited virtual call reminders',
      'Advanced TTS call readouts',
      'Unlimited voice scheduling',
      'Daily, weekly & monthly recurring reminders',
      'Smart reminder customization',
      'Priority support',
      'Early access to new features',
    ],
  ),
  PlanConfig(
    id: kBasePlanQuarterly,
    title: 'Premium Quarterly',
    tagline: 'Save more every 3 months',
    fallbackPrice: r'$1.56 / 3 months',
    badge: 'Short-Term Value',
    features: [
      'Everything in Premium Monthly',
      'Discounted subscription pricing',
      'Reduced cost compared to monthly billing',
      'Best short-term value',
    ],
  ),
  PlanConfig(
    id: kBasePlanYearly,
    title: 'Premium Yearly',
    tagline: 'Best value for committed users',
    fallbackPrice: r'$5.31/year',
    badge: 'Best Value',
    features: [
      'Everything in Premium Quarterly',
      'Biggest savings on subscription',
      'Full premium access for 12 months',
      'Best overall value',
    ],
  ),
  PlanConfig(
    id: kProductIdLifetime,
    title: 'Lifetime Premium',
    tagline: 'One payment. Forever yours.',
    fallbackPrice: r'$12.50',
    badge: '⭐ Early Bird',
    isOneTime: true,
    features: [
      'Everything in Premium Yearly',
      'Lifetime premium access',
      'No recurring payments',
      'Exclusive early supporter badge',
      'Access to future premium upgrades during early bird period',
    ],
  ),
];

// ─── SubscriptionStatus Entity ────────────────────────────────────────────────

enum SubscriptionTier { free, premium }

class SubscriptionStatus {
  final SubscriptionTier tier;

  /// The product ID (or base plan ID) of the active plan, or null if free.
  final String? activeProductId;

  /// Estimated expiry for recurring subs. Null for lifetime or free.
  final DateTime? expiryDate;

  final bool isLifetime;

  /// Purchase token for server-side verification.
  final String? purchaseToken;

  const SubscriptionStatus({
    required this.tier,
    this.activeProductId,
    this.expiryDate,
    this.isLifetime = false,
    this.purchaseToken,
  });

  static const SubscriptionStatus defaultFree = SubscriptionStatus(
    tier: SubscriptionTier.free,
  );

  bool get isActive => tier == SubscriptionTier.premium;

  bool get isExpired {
    if (!isActive || isLifetime) return false;
    return expiryDate != null && DateTime.now().isAfter(expiryDate!);
  }

  // ─── Firestore (de)serialisation ─────────────────────────────────────────

  factory SubscriptionStatus.fromFirestore(Map<String, dynamic> data) {
    final dynamic rawExpiry = data['subscriptionExpiryDate'];
    return SubscriptionStatus(
      tier: data['subscriptionTier'] == 'premium'
          ? SubscriptionTier.premium
          : SubscriptionTier.free,
      activeProductId: data['productId'] as String?,
      expiryDate: rawExpiry is Timestamp ? rawExpiry.toDate() : null,
      isLifetime: data['isLifetime'] as bool? ?? false,
      purchaseToken: data['purchaseToken'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'subscriptionTier': tier == SubscriptionTier.premium ? 'premium' : 'free',
    'productId': activeProductId,
    'subscriptionExpiryDate':
        expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
    'isLifetime': isLifetime,
    'purchaseToken': purchaseToken,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  String toString() =>
      'SubscriptionStatus(tier: $tier, productId: $activeProductId, '
      'lifetime: $isLifetime, expiry: $expiryDate)';
}
