// lib/presentation/screens/onboarding/onboarding_screen.dart

import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/blocs/auth/auth_bloc.dart';
import 'package:ringtask/blocs/auth/auth_event.dart';
import 'package:ringtask/blocs/onboarding/onboarding_bloc.dart';
import 'package:ringtask/core/constants/app_assets.dart';
import 'package:ringtask/core/di/service_locator.dart';
import 'package:ringtask/data/datasources/local/cache_manager.dart';
import 'package:ringtask/presentation/widgets/custom_button.dart';
import 'package:ringtask/router.dart';
import 'package:ringtask/services/firebase/fake_call_service.dart';

import 'package:ringtask/utils/logger.dart';

enum OnboardingPermissionType { notifications, overlay }

class OnboardingPageData {
  final String title;
  final String subtitle;
  final String asset;
  final bool isPermissionPage;
  final OnboardingPermissionType? permissionType;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.asset,
    this.isPermissionPage = false,
    this.permissionType,
  });
}

const List<OnboardingPageData> _kPages = [
  OnboardingPageData(
    title: 'Stay Organized, Stay Ahead.',
    subtitle:
    'Manage all your tasks, deadlines, and priorities in one intelligent workspace.',
    asset: AppAssets.onboarding1,
  ),
  OnboardingPageData(
    title: 'Smarter Reminders.\nStronger Results.',
    subtitle:
    'RingTask uses intelligent virtual call reminders so you never miss what matters.',
    asset: AppAssets.onboarding2,
  ),
  OnboardingPageData(
    title: 'Virtual Call Reminders\nYou Can\'t Ignore.',
    subtitle:
    'When a task is due, RingTask calls you — just like a real incoming call.',
    asset: AppAssets.onboarding3,
  ),
  OnboardingPageData(
    title: 'Smart Work.\nBetter Productivity.',
    subtitle:
    'Let RingTask handle the reminders while you focus on what truly matters.',
    asset: AppAssets.onboarding4,
  ),
  OnboardingPageData(
    title: 'Hear Your Tasks.\nTake Action.',
    subtitle:
    'Answer the call and listen to your task details using natural text-to-speech.',
    asset: AppAssets.onboarding5,
  ),
  OnboardingPageData(
    title: 'Your Productivity\nPartner for Life.',
    subtitle:
    'From reminders to achievements, RingTask is with you at every step of your journey.',
    asset: AppAssets.onboarding6,
  ),
  OnboardingPageData(
    title: 'Almost There!\nStay Notified.',
    subtitle:
    'RingTask needs notification permission to remind you of your tasks at the right time.',
    asset: AppAssets.onboarding2,
    isPermissionPage: true,
    permissionType: OnboardingPermissionType.notifications,
  ),
  OnboardingPageData(
    title: 'Appear on Top.\nNever Miss a Call.',
    subtitle:
    'To show the incoming call screen over other apps, RingTask needs the "Appear on Top" permission. You will be taken to system settings to enable this.',
    asset: AppAssets.onboarding3,
    isPermissionPage: true,
    permissionType: OnboardingPermissionType.overlay,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _kPages.length - 1;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _precacheAllAssets();
      // Permissions are now requested on the dedicated onboarding page
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _precacheAllAssets() async {
    if (!mounted) return;

    final allAssets = [
      ..._kPages.map((p) => p.asset),
    ];

    await Future.wait(
      allAssets.map(
            (path) => precacheImage(AssetImage(path), context).catchError((e) {
          AppLogger.warning('⚠️ Precache failed for $path: $e');
        }),
      ),
    );

    AppLogger.info('✅ All onboarding assets precached');
  }

  // Removed _initializeServicesInBackground, _initAlarmScheduler, 
  // _initFakeCallService, and _initVoiceService as they are now global.

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _skipToLast() {
    _pageController.animateToPage(
      _kPages.length - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onOnboardingComplete(BuildContext context) {
    if (!context.mounted) return;

    try {
      context.read<AuthBloc>().add(const AppStarted());
    } catch (e) {
      Navigator.of(context).pushReplacementNamed(AppRouter.loginRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Choose a max content width for larger screens (tablets / web)
    const double kMaxContentWidth = 1100.0;

    return BlocProvider(
      create: (_) => OnboardingBloc(
        cacheManager: getIt<CacheManager>(),
      ),
      child: Builder(
        builder: (context) {
          return BlocListener<OnboardingBloc, OnboardingState>(
            listenWhen: (previous, current) =>
            !previous.isComplete && current.isComplete,
            listener: (context, _) => _onOnboardingComplete(context),
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: SafeArea(
                child: LayoutBuilder(builder: (context, constraints) {
                  final maxWidth = min(constraints.maxWidth, kMaxContentWidth);

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        maxHeight: constraints.maxHeight,
                      ),
                      child: Card(
                        elevation: 6,
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 16.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 18.0),
                          child: Column(
                            children: [
                              // PageView (Expanded to take available space)
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _kPages.length,
                                  onPageChanged: (index) {
                                    setState(() => _currentPage = index);
                                    context
                                        .read<OnboardingBloc>()
                                        .add(OnboardingPageChanged(index));
                                  },
                                  itemBuilder: (_, index) =>
                                      LayoutBuilder(builder: (context, constraints) {
                                        return _OnboardingCardPage(
                                          data: _kPages[index],
                                          maxPageHeight: constraints.maxHeight,
                                          onGrantPermissions: () async {
                                            final type = _kPages[index].permissionType;
                                            if (type == OnboardingPermissionType.notifications) {
                                              await getIt<FakeCallService>().requestNotificationAndAlarmPermissions();
                                            } else if (type == OnboardingPermissionType.overlay) {
                                              await getIt<FakeCallService>().requestSystemAlertWindowPermission();
                                            }
                                          },
                                        );
                                      }),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Bottom navigation area (skip/dots/next or Get started)
                              _isLastPage
                                  ? _GetStartedBottom(
                                onGetStarted: () => context
                                    .read<OnboardingBloc>()
                                    .add(const OnboardingCompleted()),
                              )
                                  : _NavigationBar(
                                currentPage: _currentPage,
                                totalPages: _kPages.length,
                                onSkip: () {
                                  _skipToLast();
                                  context
                                      .read<OnboardingBloc>()
                                      .add(const OnboardingSkipTapped());
                                },
                                onNext: () {
                                  _nextPage();
                                  context
                                      .read<OnboardingBloc>()
                                      .add(const OnboardingNextTapped());
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Internal per-page widget adapted to the card layout
class _OnboardingCardPage extends StatelessWidget {
  final OnboardingPageData data;
  final double maxPageHeight;
  final VoidCallback? onGrantPermissions;

  const _OnboardingCardPage({
    required this.data,
    required this.maxPageHeight,
    this.onGrantPermissions,
  });

  @override
  Widget build(BuildContext context) {
    // Reserve about 75% of the page box for image, remaining for text
    final imageMaxHeight = maxPageHeight * 0.75;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          children: [
            // Image box with rounded background to look polished
            Container(
              height: imageMaxHeight,
              decoration: BoxDecoration(
                color: Color(AppAssets.backgroundColor),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  data.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 72,
                      color: Colors.white
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.titleLarge?.color,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.blueGrey,
                height: 1.55,
              ),
            ),
            if (data.isPermissionPage) ...[
              const SizedBox(height: 24),
              CustomButton(
                text: 'Grant Permissions',
                onPressed: onGrantPermissions ?? () {},
                color: Color(AppAssets.primaryVariant),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// Navigation and bottom widgets (kept largely the same, but paddings adjusted)

class _NavigationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _NavigationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: onSkip,
            child: Text(
              'Skip',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          _DotIndicator(totalDots: totalPages, currentIndex: currentPage),
          TextButton(
            onPressed: onNext,
            child: Text(
              'Next',
              style: TextStyle(
                color: Color(AppAssets.primaryColor),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GetStartedBottom extends StatelessWidget {
  final VoidCallback onGetStarted;

  const _GetStartedBottom({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: Column(
        children: [
          CustomButton(
            text: 'Get Started',
            onPressed: onGetStarted,
            color: Color(AppAssets.primaryColor),
          ),
          const SizedBox(height: 10),
          Text(
            "Let's boost your productivity!",
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int totalDots;
  final int currentIndex;

  const _DotIndicator({
    required this.totalDots,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalDots, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Color(AppAssets.primaryColor)
                : Color(AppAssets.primaryColor).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}