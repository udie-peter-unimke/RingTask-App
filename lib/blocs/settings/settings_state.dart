import 'package:equatable/equatable.dart';
import 'package:ringtask/data/models/settings_model.dart';

/// Base class for all Settings states
abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before settings are loaded
class SettingsInitial extends SettingsState {
  const SettingsInitial();

  @override
  String toString() => 'SettingsInitial';
}

/// State when settings are being loaded initially
class SettingsLoading extends SettingsState {
  const SettingsLoading();

  @override
  String toString() => 'SettingsLoading';
}

/// State when settings are successfully loaded
class SettingsLoaded extends SettingsState {
  final SettingsModel settings;
  final DateTime loadedAt;

  SettingsLoaded(
      this.settings, {
        DateTime? loadedAt,
      }) : loadedAt = loadedAt ?? DateTime.now();

  /// Creates a copy of this state with updated values
  SettingsLoaded copyWith({
    SettingsModel? settings,
    DateTime? loadedAt,
  }) {
    return SettingsLoaded(
      settings ?? this.settings,
      loadedAt: loadedAt ?? this.loadedAt,
    );
  }

  @override
  List<Object?> get props => [settings, loadedAt];

  @override
  String toString() => 'SettingsLoaded { settings: $settings, loadedAt: $loadedAt }';
}

/// State when settings are being updated/saved
class SettingsUpdating extends SettingsState {
  final SettingsModel currentSettings;
  final SettingsModel pendingSettings;
  final DateTime startedAt;

  SettingsUpdating({
    required this.currentSettings,
    required this.pendingSettings,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  @override
  List<Object?> get props => [currentSettings, pendingSettings, startedAt];

  @override
  String toString() => 'SettingsUpdating { '
      'current: $currentSettings, '
      'pending: $pendingSettings, '
      'startedAt: $startedAt '
      '}';
}

/// State when settings are successfully updated
class SettingsUpdateSuccess extends SettingsState {
  final SettingsModel settings;
  final String? successMessage;
  final DateTime updatedAt;

  SettingsUpdateSuccess({
    required this.settings,
    this.successMessage,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  @override
  List<Object?> get props => [settings, successMessage, updatedAt];

  @override
  String toString() => 'SettingsUpdateSuccess { '
      'settings: $settings, '
      'message: $successMessage, '
      'updatedAt: $updatedAt '
      '}';
}

/// State when settings reset is in progress
class SettingsResetting extends SettingsState {
  final SettingsModel currentSettings;
  final DateTime startedAt;

  SettingsResetting({
    required this.currentSettings,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  @override
  List<Object?> get props => [currentSettings, startedAt];

  @override
  String toString() => 'SettingsResetting { startedAt: $startedAt }';
}

/// State when settings are successfully reset to defaults
class SettingsResetSuccess extends SettingsState {
  final SettingsModel defaultSettings;
  final DateTime resetAt;

  SettingsResetSuccess({
    required this.defaultSettings,
    DateTime? resetAt,
  }) : resetAt = resetAt ?? DateTime.now();

  @override
  List<Object?> get props => [defaultSettings, resetAt];

  @override
  String toString() => 'SettingsResetSuccess { '
      'settings: $defaultSettings, '
      'resetAt: $resetAt '
      '}';
}

/// State when there's an error with settings operations
class SettingsError extends SettingsState {
  final String message;
  final String? errorCode;
  final dynamic error;
  final StackTrace? stackTrace;
  final DateTime occurredAt;
  final SettingsModel? lastKnownSettings;

  SettingsError({
    required this.message,
    this.errorCode,
    this.error,
    this.stackTrace,
    DateTime? occurredAt,
    this.lastKnownSettings,
  }) : occurredAt = occurredAt ?? DateTime.now();

  @override
  List<Object?> get props => [
    message,
    errorCode,
    error,
    stackTrace,
    occurredAt,
    lastKnownSettings,
  ];

  @override
  String toString() => 'SettingsError { '
      'message: $message, '
      'code: $errorCode, '
      'time: $occurredAt, '
      'hasLastKnown: ${lastKnownSettings != null} '
      '}';
}

/// State when settings sync is in progress (for multi-device sync)
class SettingsSyncing extends SettingsState {
  final SettingsModel currentSettings;
  final DateTime syncStartedAt;

  SettingsSyncing({
    required this.currentSettings,
    DateTime? syncStartedAt,
  }) : syncStartedAt = syncStartedAt ?? DateTime.now();

  @override
  List<Object?> get props => [currentSettings, syncStartedAt];

  @override
  String toString() => 'SettingsSyncing { syncStartedAt: $syncStartedAt }';
}

/// State when settings sync is complete
class SettingsSyncSuccess extends SettingsState {
  final SettingsModel syncedSettings;
  final DateTime syncedAt;
  final bool hadConflicts;

  SettingsSyncSuccess({
    required this.syncedSettings,
    DateTime? syncedAt,
    this.hadConflicts = false,
  }) : syncedAt = syncedAt ?? DateTime.now();

  @override
  List<Object?> get props => [syncedSettings, syncedAt, hadConflicts];

  @override
  String toString() => 'SettingsSyncSuccess { '
      'syncedAt: $syncedAt, '
      'hadConflicts: $hadConflicts '
      '}';
}