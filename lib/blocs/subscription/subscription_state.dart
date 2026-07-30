// lib/blocs/subscription/subscription_state.dart
part of 'subscription_bloc.dart';

abstract class SubscriptionState extends Equatable {
  const SubscriptionState();
  @override
  List<Object?> get props => [];
}

/// Before [InitialiseSubscription] has been fired.
class SubscriptionInitial extends SubscriptionState {}

/// Fetching products and status from Play Billing + Firestore.
class SubscriptionLoading extends SubscriptionState {}

/// Products and status successfully loaded. UI renders plan cards.
class SubscriptionLoaded extends SubscriptionState {
  final SubscriptionStatus status;
  final List<ProductDetails> products;

  /// Product ID currently highlighted in the UI (user selection).
  final String? selectedProductId;

  const SubscriptionLoaded({
    required this.status,
    required this.products,
    this.selectedProductId,
  });

  SubscriptionLoaded copyWith({
    SubscriptionStatus? status,
    List<ProductDetails>? products,
    String? selectedProductId,
  }) {
    return SubscriptionLoaded(
      status: status ?? this.status,
      products: products ?? this.products,
      selectedProductId: selectedProductId ?? this.selectedProductId,
    );
  }

  @override
  List<Object?> get props => [status, products, selectedProductId];
}

/// Play Billing purchase sheet is open / purchase is pending.
class SubscriptionPurchasing extends SubscriptionState {
  final SubscriptionStatus currentStatus;
  final List<ProductDetails> products;
  final String purchasingProductId;

  const SubscriptionPurchasing({
    required this.currentStatus,
    required this.products,
    required this.purchasingProductId,
  });

  @override
  List<Object?> get props => [currentStatus, products, purchasingProductId];
}

/// Purchase completed and saved to Firestore.
class SubscriptionPurchaseSuccess extends SubscriptionState {
  final SubscriptionStatus newStatus;

  const SubscriptionPurchaseSuccess({required this.newStatus});

  @override
  List<Object?> get props => [newStatus];
}

/// Something went wrong. [lastStatus] / [products] let the UI recover
/// without reloading from scratch.
class SubscriptionError extends SubscriptionState {
  final String message;
  final SubscriptionStatus? lastStatus;
  final List<ProductDetails>? products;

  const SubscriptionError({
    required this.message,
    this.lastStatus,
    this.products,
  });

  @override
  List<Object?> get props => [message];
}