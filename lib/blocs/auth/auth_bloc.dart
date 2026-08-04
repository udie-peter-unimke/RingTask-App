import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/repositories/auth_repository.dart';
import 'package:ringtask/core/di/service_locator.dart'; // Required for getIt
import 'package:ringtask/data/datasources/local/cache_manager.dart'; // Required for cache check
import 'package:ringtask/services/entitlement/entitlement_service.dart';
import 'package:ringtask/utils/logger.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthLoading()) {
    on<AppStarted>(_onAppStarted);
    on<SignUpRequested>(_onSignUpRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<GoogleSignUpRequested>(_onGoogleSignUpRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
    on<RefreshUserRequested>(_onRefreshUserRequested);
    on<PasswordResetRequested>(_onPasswordResetRequested);
  }

  /// Check if user is already logged in on app start
  Future<void> _onAppStarted(
      AppStarted event,
      Emitter<AuthState> emit,
      ) async {
    try {
      // 1. Explicitly ensure loading state is active during initialization
      emit(AuthLoading());

      AppLogger.info('AuthBloc: Initializing app startup check...');

      // 2. Intercept startup to check onboarding completion status first
      final cacheManager = getIt<CacheManager>();
      final hasSeenOnboarding = await cacheManager.hasSeenOnboarding();
      AppLogger.info('AuthBloc: Onboarding seen status: $hasSeenOnboarding');

      if (!hasSeenOnboarding) {
        AppLogger.info('AuthBloc: Emitting AuthOnboardingRequired');
        emit(AuthOnboardingRequired());
        return; // Stop execution here so user gets guided to OnboardingScreen
      }

      // 3. Authentication verification logic
      final isLoggedIn = await authRepository.isUserLoggedIn();
      AppLogger.info('AuthBloc: User logged in: $isLoggedIn');

      if (isLoggedIn) {
        try {
          final user = await authRepository.getCurrentUser();
          if (user != null) {
            // Initialize EntitlementService on startup
            await getIt<EntitlementService>().initialize(user.id);

            AppLogger.info('AuthBloc: Emitting AuthSuccess for ${user.id}');
            emit(AuthSuccess(
              uid: user.id,
              name: user.displayName,
              email: user.email,
            ));
            return;
          }
        } catch (innerError, innerStack) {
          // Network error or timeout occurred during profile fetch, but user is authenticated locally
          AppLogger.warning(
              'AuthBloc: Profile fetch failed during startup, falling back to offline session data.',
              error: innerError,
              stackTrace: innerStack);

          // Emit AuthSuccess with fallback basic configurations to prevent login loop
          emit(const AuthSuccess(
            uid: 'offline_cached_user', // Provide basic data safely matching your domain schema
            name: 'RingTask User',
            email: '',
          ));
          return;
        }
      }

      AppLogger.info('AuthBloc: Emitting AuthInitial (Login required)');
      emit(AuthInitial());
    } catch (e, stack) {
      AppLogger.error('AuthBloc: Critical startup check failed', error: e, stackTrace: stack);
      // Graceful fallback to initial screen state if cache or repository fails entirely
      emit(AuthInitial());
    }
  }

  /// 🔐 Email/password signup
  Future<void> _onSignUpRequested(
      SignUpRequested event,
      Emitter<AuthState> emit,
      ) async {
    if (event.password != event.confirmPassword) {
      emit(const AuthFailure(error: 'Passwords do not match'));
      return;
    }

    try {
      emit(AuthLoading());

      final user = await authRepository.signup(
        event.email,
        event.password,
        event.name,
      );

      if (user != null) {
        // Initialize EntitlementService after login/signup
        await getIt<EntitlementService>().initialize(user.id);

        emit(AuthSuccess(
          uid: user.id,
          name: user.displayName,
          email: user.email,
        ));
      } else {
        emit(const AuthFailure(error: 'Signup failed'));
      }
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  /// 🔑 Email/password login
  Future<void> _onLoginRequested(
      LoginRequested event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(AuthLoading());

      final user = await authRepository.login(
        event.email,
        event.password,
      );

      if (user != null) {
        // Initialize EntitlementService after login/signup
        await getIt<EntitlementService>().initialize(user.id);

        emit(AuthSuccess(
          uid: user.id,
          name: user.displayName,
          email: user.email,
        ));
      } else {
        emit(const AuthFailure(error: 'Invalid email or password'));
      }
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  /// 🚪 Logout
  Future<void> _onLogoutRequested(
      LogoutRequested event,
      Emitter<AuthState> emit,
      ) async {
    try {
      await authRepository.logout();
      emit(AuthInitial());
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  /// 🔵 Google sign-in
  Future<void> _onGoogleSignUpRequested(
      GoogleSignUpRequested event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(AuthLoading());

      final user = await authRepository.signInWithGoogle();

      if (user != null) {
        // 1. Validate ID token exists implicitly via successful user return
        // Initialize EntitlementService after successful Google Sign-In
        await getIt<EntitlementService>().initialize(user.id);

        emit(AuthSuccess(
          uid: user.id,
          name: user.displayName,
          email: user.email,
        ));
      } else {
        // 2. Handle null safely (User explicitly closed/canceled the overlay)
        AppLogger.info('AuthBloc: Google Sign-In canceled by user.');
        emit(AuthInitial());
      }
    } catch (e, stack) {
      AppLogger.error('Google Sign-In error in BLoC', error: e, stackTrace: stack);

      final errorMessage = e.toString();

      // 3 & 4. Auto sign-out on failure to fix the "[16] Account reauth failed" loop
      // This forces the platform-level channel to clear internal cache states
      if (errorMessage.contains('16') || errorMessage.contains('reauth')) {
        AppLogger.warning('AuthBloc: API 16 loop detected. Executing proactive Google session clear...');
        try {
          await authRepository.logout();
        } catch (logoutError) {
          AppLogger.error('AuthBloc: Failed to clear session during fallback', error: logoutError);
        }
      }

      emit(const AuthFailure(
        error: 'Google Sign-In failed or was interrupted. Please try again.',
      ));
    }
  }

  /// 🗑 Delete account (currently logs out)
  Future<void> _onDeleteAccountRequested(
      DeleteAccountRequested event,
      Emitter<AuthState> emit,
      ) async {
    try {
      await authRepository.logout();
      emit(AuthInitial());
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  /// 🔄 Refresh current user
  Future<void> _onRefreshUserRequested(
      RefreshUserRequested event,
      Emitter<AuthState> emit,
      ) async {
    try {
      final user = await authRepository.getCurrentUser();

      if (user != null) {
        // Initialize EntitlementService after login/signup
        await getIt<EntitlementService>().initialize(user.id);

        emit(AuthSuccess(
          uid: user.id,
          name: user.displayName,
          email: user.email,
        ));
      } else {
        emit(AuthInitial());
      }
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  /// 🔁 Password reset
  Future<void> _onPasswordResetRequested(
      PasswordResetRequested event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(AuthLoading());

      final success = await authRepository.resetPassword(event.email);

      if (success) {
        emit(AuthInitial());
      } else {
        emit(const AuthFailure(error: 'Password reset failed'));
      }
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }
}