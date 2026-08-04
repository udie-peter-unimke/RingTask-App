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
import 'package:ringtask/presentation/screens/onboarding/widgets/onboarding_page.dart';

import 'package:ringtask/utils/logger.dart';

const List<OnboardingPageData> _kPages = [
  OnboardingPageData(
    titleLine1: 'Stay Organized,',
    titleLine2: 'Stay Ahead.',
    subtitle:
        'Manage all your tasks, deadlines, and priorities in one intelligent workspace.',
    assetPath: AppAssets.onboarding1,
  ),
  OnboardingPageData(
    titleLine1: 'Smarter Reminders.',
    titleLine2: 'Stronger Results.',
    subtitle:
        'RingTask uses intelligent virtual call reminders so you never miss what matters.',
    assetPath: AppAssets.onboarding2,
  ),
  OnboardingPageData(
    titleLine1: 'Virtual Call Reminders',
    titleLine2: 'You Can\'t Ignore.',
    subtitle:
        'When a task is due, RingTask calls you — just like a real incoming call.',
    assetPath: AppAssets.onboarding3,
  ),
  OnboardingPageData(
    titleLine1: 'Smart Work.',
    titleLine2: 'Better Productivity.',
    subtitle:
        'Let RingTask handle the reminders while you focus on what truly matters.',
    assetPath: AppAssets.onboarding4,
  ),
  OnboardingPageData(
    titleLine1: 'Hear Your Tasks.',
    titleLine2: 'Take Action.',
    subtitle:
        'Answer the call and listen to your task details using natural text-to-speech.',
    assetPath: AppAssets.onboarding5,
  ),
  OnboardingPageData(
    titleLine1: 'Your Productivity',
    titleLine2: 'Partner for Life.',
    subtitle:
        'From reminders to achievements, RingTask is with you at every step of your journey.',
    assetPath: AppAssets.onboarding6,
  ),
  OnboardingPageData(
    titleLine1: 'Almost There!',
    titleLine2: 'Stay Notified.',
    subtitle:
        'RingTask needs notification permission to remind you of your tasks at the right time.',
    assetPath: AppAssets.onboarding2,
    permissionType: OnboardingPermissionType.notifications,
  ),
  OnboardingPageData(
    titleLine1: 'Appear on Top.',
    titleLine2: 'Never Miss a Call.',
    subtitle:
        'To show the incoming call screen over other apps, RingTask needs the "Appear on Top" permission. You will be taken to system settings to enable this.',
    assetPath: AppAssets.onboarding3,
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
      ..._kPages.map((p) => p.assetPath),
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
      // Retrigger the global initialization flow so AuthBloc checks session state
      context.read<AuthBloc>().add(AppStarted());
    } catch (e) {
      AppLogger.error('Failed to notify AuthBloc from OnboardingScreen', error: e);
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
                                  // 🔑 FIXED: Retains current page pointer across settings/theme changes
                                  key: const PageStorageKey(
                                      'onboarding_page_view'),
                                  controller: _pageController,
                                  itemCount: _kPages.length,
                                  onPageChanged: (index) {
                                    setState(() => _currentPage = index);
                                    context
                                        .read<OnboardingBloc>()
                                        .add(OnboardingPageChanged(index));
                                  },
                                  itemBuilder: (_, index) => OnboardingPage(
                                    data: _kPages[index],
                                    onPermissionRequest: () async {
                                      final type =
                                          _kPages[index].permissionType;
                                      if (type ==
                                          OnboardingPermissionType
                                              .notifications) {
                                        await getIt<FakeCallService>()
                                            .requestNotificationAndAlarmPermissions();
                                      } else if (type ==
                                          OnboardingPermissionType.overlay) {
                                        await getIt<FakeCallService>()
                                            .requestSystemAlertWindowPermission();
                                      }
                                    },
                                  ),
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