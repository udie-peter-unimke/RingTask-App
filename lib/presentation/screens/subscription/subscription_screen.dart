// lib/presentation/screens/subscription/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ringtask/blocs/subscription/subscription_bloc.dart';
import 'package:ringtask/entities/subscription_entities.dart';
import 'package:ringtask/presentation/screens/subscription/widgets/plan_card.dart';
import 'package:ringtask/presentation/widgets/custom_button.dart';
import 'package:ringtask/presentation/widgets/loading_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _selectedPlanId = kBasePlanYearly;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<SubscriptionBloc>().add(InitialiseSubscription(uid: user.uid));
    }
  }

  void _onPurchaseTapped(SubscriptionLoaded state) {
    final plan = kSubscriptionPlans.firstWhere((p) => p.id == _selectedPlanId);
    
    ProductDetails? targetProduct;
    if (plan.isOneTime) {
      targetProduct = state.products.firstWhere(
        (p) => p.id == kProductIdLifetime,
        orElse: () => throw Exception('Lifetime product not found'),
      );
    } else {
      // For base plans under one subscription ID
      targetProduct = state.products.firstWhere(
        (p) => p.id == kProductIdPremiumSubscription,
        orElse: () => throw Exception('Subscription product not found'),
      );
    }

    context.read<SubscriptionBloc>().add(PurchaseProduct(product: targetProduct));
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RingTask Premium'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionPurchaseSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Welcome to Premium! Your features are now unlocked.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          } else if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is SubscriptionLoading || state is SubscriptionInitial) {
            return const Center(child: LoadingIndicator());
          }

          SubscriptionStatus status = SubscriptionStatus.defaultFree;
          List<ProductDetails> products = [];
          bool isPurchasing = false;

          if (state is SubscriptionLoaded) {
            status = state.status;
            products = state.products;
          } else if (state is SubscriptionPurchasing) {
            status = state.currentStatus;
            products = state.products;
            isPurchasing = true;
          }

          if (status.isActive) {
            return _buildAlreadyPremium(status);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                ...kSubscriptionPlans.map((plan) {
                  // Find price if available
                  String? displayPrice;
                  try {
                    if (plan.isOneTime) {
                      final p = products.firstWhere((p) => p.id == kProductIdLifetime);
                      displayPrice = p.price;
                    } else {
                      // Note: Standard IAP plugin doesn't easily split base plans.
                      // We'll use fallback prices from PlanConfig unless we have separate IDs.
                      // If the user set up 3 separate products, this would work:
                      // final p = products.firstWhere((p) => p.id == plan.id);
                      // displayPrice = p.price;
                    }
                  } catch (_) {}

                  return PlanCard(
                    plan: plan,
                    price: displayPrice,
                    isSelected: _selectedPlanId == plan.id,
                    onTap: () => setState(() => _selectedPlanId = plan.id),
                  );
                }),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Upgrade Now',
                  isLoading: isPurchasing,
                  onPressed: state is SubscriptionLoaded 
                      ? () => _onPurchaseTapped(state) 
                      : null,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        context.read<SubscriptionBloc>().add(RestorePurchases(uid: user.uid));
                      }
                    },
                    child: const Text('Restore Purchases'),
                  ),
                ),
                const SizedBox(height: 32),
                _buildExclusiveFeatures(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock the full power of smart productivity with RingTask Premium.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  Widget _buildExclusiveFeatures() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Exclusive Features',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _FeatureItem(
          icon: Icons.call_rounded,
          title: 'Virtual Call Reminder',
          description: 'RingTask calls you instead of sending regular notifications.',
        ),
        _FeatureItem(
          icon: Icons.mic_rounded,
          title: 'Voice Scheduling',
          description: 'Create and schedule tasks instantly using voice commands.',
        ),
        _FeatureItem(
          icon: Icons.repeat_rounded,
          title: 'Smart Recurring Tasks',
          description: 'Set reminders once for daily, weekly, or monthly repetition.',
        ),
        _FeatureItem(
          icon: Icons.record_voice_over_rounded,
          title: 'Text-to-Speech Readout',
          description: 'When you answer, RingTask reads your scheduled task and time aloud.',
        ),
        _FeatureItem(
          icon: Icons.star_rounded,
          title: 'Priority Access',
          description: 'Get early access to upcoming premium features and improvements.',
        ),
      ],
    );
  }

  Widget _buildAlreadyPremium(SubscriptionStatus status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars_rounded, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              'You are a Premium User!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              status.isLifetime 
                  ? 'You have lifetime access to all features.' 
                  : 'Your subscription is active.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Back to Tasks',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
