// lib/blocs/subscription/subscription_event.dart
part of 'subscription_bloc.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();
  @override
  List<Object?> get props => [];
}

/// Fired on page open. Fetches products + current status in parallel.
class InitialiseSubscription extends SubscriptionEvent {
  final String uid;
  const InitialiseSubscription({required this.uid});
  @override
  List<Object?> get props => [uid];
}

/// Fired when the user taps a purchase / subscribe button.
class PurchaseProduct extends SubscriptionEvent {
  final ProductDetails product;
  const PurchaseProduct({required this.product});
  @override
  List<Object?> get props => [product.id];
}

/// Fired when the user taps "Restore purchases".
class RestorePurchases extends SubscriptionEvent {
  final String uid;
  const RestorePurchases({required this.uid});
  @override
  List<Object?> get props => [uid];
}

/// Internal — dispatched automatically when [purchaseUpdates] emits.
/// Prefixed with _ so it cannot be added from outside this library.
class _PurchaseUpdated extends SubscriptionEvent {
  final List<PurchaseDetails> purchases;
  const _PurchaseUpdated({required this.purchases});
  @override
  List<Object?> get props => [purchases];
}