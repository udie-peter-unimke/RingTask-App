import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ringtask/entities/subscription_entities.dart';

/// Contract between the BLoC and the data layer.
/// Concrete implementation: [SubscriptionRepositoryImpl].
abstract class SubscriptionRepository {
  /// Returns all [ProductDetails] fetched live from Google Play Billing.
  /// Throws on network/billing error.
  Future<List<ProductDetails>> getProducts();

  /// Launches the Play Billing purchase sheet for [product].
  /// Returns true if the sheet was displayed. Actual result arrives via
  /// [purchaseUpdates].
  Future<bool> initiatePurchase(ProductDetails product);

  /// Triggers a restore flow for previous purchases.
  /// Results arrive via [purchaseUpdates].
  Future<void> restorePurchases();

  /// Reads the user's current subscription status from Firestore.
  Future<SubscriptionStatus> getSubscriptionStatus(String uid);

  /// Persists a successful purchase to Firestore (merged write).
  Future<void> saveSubscriptionStatus(String uid, SubscriptionStatus status);

  /// Must be called after handling a purchase to acknowledge it with Google.
  Future<void> completeIapPurchase(PurchaseDetails details);

  /// Live stream of purchase state changes from the Play Billing client.
  /// The BLoC subscribes to this to handle async purchase outcomes.
  Stream<List<PurchaseDetails>> get purchaseUpdates;
}
