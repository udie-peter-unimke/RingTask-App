import 'package:equatable/equatable.dart';
import '../../data/models/loop_model.dart';

/// Base class for all loop-related states
abstract class LoopState extends Equatable {
  const LoopState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class LoopInitial extends LoopState {
  const LoopInitial();
}

/// Loading state while fetching tasks from Firestore
class LoopLoading extends LoopState {
  const LoopLoading();
}

/// Successfully loaded tasks from Firestore
class LoopLoaded extends LoopState {
  final List<TaskLoopItem> tasks;
  final String? message; // For snackbars, success notifications

  const LoopLoaded(this.tasks, {this.message});

  @override
  List<Object?> get props => [tasks, message];
}

/// Error state when an operation fails
class LoopError extends LoopState {
  final String message;

  const LoopError(this.message);

  @override
  List<Object?> get props => [message];
}