import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

// ✅ Added — required by AuthBloc._onAppStarted
class AuthOnboardingRequired extends AuthState {}

class AuthSuccess extends AuthState {
  final String uid;
  final String name;
  final String? email;

  const AuthSuccess({
    required this.uid,
    required this.name,
    this.email,
  });

  @override
  // 🔴 Fixed — was only [name], missing uid and email
  //    Equatable uses props for == and hashCode, incomplete props
  //    means two different AuthSuccess states could appear equal
  List<Object?> get props => [uid, name, email];
}

class AuthFailure extends AuthState {
  final String error;

  const AuthFailure({required this.error});

  @override
  List<Object?> get props => [error];
}