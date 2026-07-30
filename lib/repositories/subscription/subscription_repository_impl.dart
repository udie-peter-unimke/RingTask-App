// lib/repositories/subscription/subscription_repository_impl.dart

import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ringtask/data/datasources/local/subscription_local_datasource.dart';
import 'package:ringtask/data/datasources/remote/subscription_remote_datasource.dart';
import 'package:ringtask/entities/subscription_entities.dart';
import 'package:ringtask/repositories/subscription/subscription_repository.dart';
import 'package:ringtask/utils/logger.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final InAppPurchase _iap = InAppPurchase.instance;
  final SubscriptionRemoteDataSource _remoteDataSource;
  final SubscriptionLocalDataSource _localDataSource;

  SubscriptionRepositoryImpl({
    required SubscriptionRemoteDataSource remoteDataSource,
    required SubscriptionLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

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
      // 1. Try to get from local cache first for instant UI response
      final localStatus = await _localDataSource.getSubscriptionStatus();
      if (localStatus != null) {
        AppLogger.info('Retrieved subscription status from local cache: $localStatus');
      }

      // 2. Fetch from Remote
      final remoteStatus = await _remoteDataSource.getSubscriptionStatus(uid);
      if (remoteStatus == null) return localStatus ?? SubscriptionStatus.defaultFree;
      
      // 3. Update local cache with remote data
      await _localDataSource.saveSubscriptionStatus(remoteStatus);
      
      return remoteStatus;
    } catch (e) {
      AppLogger.error('Failed to get subscription status for $uid: $e');
      return (await _localDataSource.getSubscriptionStatus()) ?? SubscriptionStatus.defaultFree;
    }
  }

  @override
  Future<void> saveSubscriptionStatus(String uid, SubscriptionStatus status) async {
    try {
      // Save to both remote and local
      await Future.wait([
        _remoteDataSource.saveSubscriptionStatus(uid, status),
        _localDataSource.saveSubscriptionStatus(status),
      ]);
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
