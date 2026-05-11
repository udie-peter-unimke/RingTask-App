import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String uid;
  final String name;
  final String? email;
  final String? displayName;

  const AuthSuccess({
    required this.uid,
    required this.name,
    this.email,
    this.displayName,
});

  @override
  List<Object?> get props => [name];
}

class AuthFailure extends AuthState {
  final String error; // Error message
  final String name;  // Context name, optional but kept for compatibility

  const AuthFailure({required this.error, this.name = ''});

  @override
  List<Object?> get props => [error, name];

  String? get message => null;
}
