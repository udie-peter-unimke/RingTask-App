import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
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
      final isLoggedIn = await authRepository.isUserLoggedIn();

      if (isLoggedIn) {
        final user = await authRepository.getCurrentUser();
        if (user != null) {
          emit(AuthSuccess(
            uid: user.id,
            name: user.displayName,
            email: user.email,
          ));
          return;
        }
      }
      emit(AuthInitial());
    } catch (_) {
      emit(AuthInitial());
    }
  }

  /// 🔐 Email/password signup
  Future<void> _onSignUpRequested(
      SignUpRequested event,
      Emitter<AuthState> emit,
      ) async {
    // ✅ Bloc-level validation (IMPORTANT)
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
        emit(AuthSuccess(
          uid: user.id,
          name: user.displayName,
          email: user.email,
        ));
      } else {
        emit(const AuthFailure(error: 'Google Sign-In failed'));
      }
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
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
