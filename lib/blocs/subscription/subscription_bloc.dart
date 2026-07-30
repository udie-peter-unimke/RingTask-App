// lib/blocs/subscription/subscription_bloc.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ringtask/entities/subscription_entities.dart';
import 'package:ringtask/repositories/subscription/subscription_repository.dart';
import 'package:ringtask/services/entitlement/entitlement_service.dart';
import 'package:ringtask/utils/logger.dart';

part 'subscription_event.dart';
part 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final SubscriptionRepository _repository;
  final EntitlementService _entitlementService;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  String? _uid;

  SubscriptionBloc({
    required SubscriptionRepository repository,
    required EntitlementService entitlementService,
  })  : _repository = repository,
        _entitlementService = entitlementService,
        super(SubscriptionInitial()) {
    on<InitialiseSubscription>(_onInitialise);
    on<PurchaseProduct>(_onPurchase);
    on<RestorePurchases>(_onRestore);
    on<_PurchaseUpdated>(_onPurchaseUpdated);
  }

  Future<void> _onInitialise(
    InitialiseSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    _uid = event.uid;
    emit(SubscriptionLoading());

    try {
      final results = await Future.wait([
        _repository.getProducts(),
        _repository.getSubscriptionStatus(event.uid),
      ]);

      final products = results[0] as List<ProductDetails>;
      final status = results[1] as SubscriptionStatus;

      // Update EntitlementService with the latest status
      _entitlementService.updateStatus(status);

      _subscribeToStream();

      emit(SubscriptionLoaded(
        status: status,
        products: products,
        // Yearly is pre-highlighted as "Best Value".
        selectedProductId: status.activeProductId ?? kBasePlanYearly,
      ));
    } catch (e) {
      AppLogger.error('Failed to initialise subscription: $e');
      emit(SubscriptionError(message: 'Failed to load plans: $e'));
    }
  }

  Future<void> _onPurchase(
    PurchaseProduct event,
    Emitter<SubscriptionState> emit,
  ) async {
    final current = state;
    if (current is! SubscriptionLoaded) return;

    emit(SubscriptionPurchasing(
      currentStatus: current.status,
      products: current.products,
      purchasingProductId: event.product.id,
    ));

    try {
      await _repository.initiatePurchase(event.product);
    } catch (e) {
      AppLogger.error('Purchase initiation failed: $e');
      emit(SubscriptionError(
        message: 'Could not open purchase sheet: $e',
        lastStatus: current.status,
        products: current.products,
      ));
    }
  }

  Future<void> _onRestore(
    RestorePurchases event,
    Emitter<SubscriptionState> emit,
  ) async {
    _uid = event.uid;
    final current = state;

    emit(SubscriptionLoading());
    try {
      await _repository.restorePurchases();
    } catch (e) {
      AppLogger.error('Restore failed: $e');
      emit(SubscriptionError(
        message: 'Failed to restore purchases: $e',
        lastStatus: current is SubscriptionLoaded ? current.status : null,
        products: current is SubscriptionLoaded ? current.products : null,
      ));
    }
  }

  Future<void> _onPurchaseUpdated(
    _PurchaseUpdated event,
    Emitter<SubscriptionState> emit,
  ) async {
    for (final purchase in event.purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccess(purchase, emit);
          break;

        case PurchaseStatus.error:
          AppLogger.error('Purchase error: ${purchase.error}');
          emit(SubscriptionError(
            message: purchase.error?.message ?? 'Purchase failed.',
          ));
          break;

        case PurchaseStatus.canceled:
          final s = state;
          if (s is SubscriptionPurchasing) {
            emit(SubscriptionLoaded(
              status: s.currentStatus,
              products: s.products,
              selectedProductId: s.purchasingProductId,
            ));
          }
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _repository.completeIapPurchase(purchase);
      }
    }
  }

  Future<void> _handleSuccess(
    PurchaseDetails purchase,
    Emitter<SubscriptionState> emit,
  ) async {
    final isLifetime = purchase.productID == kProductIdLifetime;

    final newStatus = SubscriptionStatus(
      tier: SubscriptionTier.premium,
      activeProductId: purchase.productID,
      isLifetime: isLifetime,
      purchaseToken: purchase.verificationData.serverVerificationData,
      expiryDate: isLifetime ? null : _estimateExpiry(purchase.productID),
    );

    if (_uid != null && _uid!.isNotEmpty) {
      await _repository.saveSubscriptionStatus(_uid!, newStatus);
    }

    _entitlementService.updateStatus(newStatus);

    emit(SubscriptionPurchaseSuccess(newStatus: newStatus));
  }

  DateTime? _estimateExpiry(String productId) {
    final now = DateTime.now();
    // Note: If using base plans, the productId here might be the top-level sub ID.
    // In a real app, you'd get the actual expiry from the receipt/server.
    if (productId == kProductIdLifetime) return null;
    
    // Fallback logic for client-side estimate
    return now.add(const Duration(days: 366)); // Default to yearly if unknown
  }

  void _subscribeToStream() {
    _purchaseSub?.cancel();
    _purchaseSub = _repository.purchaseUpdates.listen(
      (purchases) => add(_PurchaseUpdated(purchases: purchases)),
      onError: (Object e) {
        AppLogger.error('Purchase stream error: $e');
      },
    );
  }

  @override
  Future<void> close() {
    _purchaseSub?.cancel();
    return super.close();
  }
}
