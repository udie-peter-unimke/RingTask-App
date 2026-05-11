import 'package:equatable/equatable.dart';

/// Base class for all authentication events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered on app startup to check current auth status
class AppStarted extends AuthEvent {
  const AppStarted();
}

/// User requests email/password login
class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// User requests email/password signup
class SignUpRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String confirmPassword;

  const SignUpRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [
    name,
    email,
    password,
    confirmPassword,
  ];
}

/// User requests Google signup/login
class GoogleSignUpRequested extends AuthEvent {
  const GoogleSignUpRequested();
}

/// User requests logout
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// User requests to delete their account
class DeleteAccountRequested extends AuthEvent {
  const DeleteAccountRequested();
}

/// Refresh current user data
class RefreshUserRequested extends AuthEvent {
  const RefreshUserRequested();
}

/// User requests password reset
class PasswordResetRequested extends AuthEvent {
  final String email;

  const PasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}
