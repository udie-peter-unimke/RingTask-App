// lib/repositories/subscription/subscription_repository_impl.dart

import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ringtask/entities/subscription_entities.dart';
import 'package:ringtask/repositories/subscription/subscription_repository.dart';
import 'package:ringtask/services/firebase/firestore_service.dart';
import 'package:ringtask/utils/logger.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirestoreService _firestoreService;

  SubscriptionRepositoryImpl({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  @override
  Future<List<ProductDetails>> getProducts() async {
    try {
      final bool available = await _iap.isAvailable();
      if (!available) {
        AppLogger.error('InAppPurchase is not available');
        throw Exception('InAppPurchase is not available');
      }

      final ProductDetailsResponse response =
          await _iap.queryProductDetails(kAllProductIds);

      if (response.error != null) {
        AppLogger.error('Error querying product details: ${response.error}');
        throw Exception(response.error!.message);
      }

      if (response.notFoundIDs.isNotEmpty) {
        AppLogger.warning('Product IDs not found: ${response.notFoundIDs}');
      }

      return response.productDetails;
    } catch (e) {
      AppLogger.error('Failed to get products: $e');
      rethrow;
    }
  }

  @override
  Future<bool> initiatePurchase(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      
      bool result;
      if (product.id == kProductIdLifetime) {
        result = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // For subscriptions, it's also non-consumable in the sense that Google handles the cycle
        result = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
      
      return result;
    } catch (e) {
      AppLogger.error('Failed to initiate purchase: $e');
      rethrow;
    }
  }

  @override
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      AppLogger.error('Failed to restore purchases: $e');
      rethrow;
    }
  }

  @override
  Future<SubscriptionStatus> getSubscriptionStatus(String uid) async {
    try {
      final data = await _firestoreService.getUserData(uid);
      if (data == null) return SubscriptionStatus.defaultFree;
      
      return SubscriptionStatus.fromFirestore(data);
    } catch (e) {
      AppLogger.error('Failed to get subscription status for $uid: $e');
      return SubscriptionStatus.defaultFree;
    }
  }

  @override
  Future<void> saveSubscriptionStatus(String uid, SubscriptionStatus status) async {
    try {
      await _firestoreService.updateUserData(uid, status.toFirestore());
      AppLogger.info('Successfully saved subscription status for $uid: $status');
    } catch (e) {
      AppLogger.error('Failed to save subscription status for $uid: $e');
      rethrow;
    }
  }

  @override
  Future<void> completeIapPurchase(PurchaseDetails details) async {
    try {
      if (details.pendingCompletePurchase) {
        await _iap.completePurchase(details);
        AppLogger.info('Completed IAP purchase: ${details.productID}');
      }
    } catch (e) {
      AppLogger.error('Failed to complete IAP purchase: $e');
      rethrow;
    }
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => _iap.purchaseStream;
}
