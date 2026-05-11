import 'package:equatable/equatable.dart';
import 'package:ringtask/data/models/settings_model.dart';

/// Base class for all Settings events
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load settings from storage
class LoadSettings extends SettingsEvent {
  final bool forceRefresh;

  const LoadSettings({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];

  @override
  String toString() => 'LoadSettings { forceRefresh: $forceRefresh }';
}

/// Event to update entire settings object
class UpdateSettings extends SettingsEvent {
  final SettingsModel settings;
  final bool showSuccessMessage;

  const UpdateSettings(
      this.settings, {
        this.showSuccessMessage = true,
      });

  @override
  List<Object?> get props => [settings, showSuccessMessage];

  @override
  String toString() => 'UpdateSettings { settings: $settings }';
}

/// Event to update notification settings only
class UpdateNotificationSettings extends SettingsEvent {
  final bool enabled;
  final String? soundPath;
  final bool vibrate;

  const UpdateNotificationSettings({
    required this.enabled,
    this.soundPath,
    this.vibrate = true,
  });

  @override
  List<Object?> get props => [enabled, soundPath, vibrate];

  @override
  String toString() => 'UpdateNotificationSettings { '
      'enabled: $enabled, '
      'sound: $soundPath, '
      'vibrate: $vibrate '
      '}';
}

/// Event to update theme settings
class UpdateThemeSettings extends SettingsEvent {
  final String themeMode; // 'light', 'dark', 'system'
  final String? primaryColor;

  const UpdateThemeSettings({
    required this.themeMode,
    this.primaryColor,
  });

  @override
  List<Object?> get props => [themeMode, primaryColor];

  @override
  String toString() => 'UpdateThemeSettings { '
      'mode: $themeMode, '
      'color: $primaryColor '
      '}';
}

/// Event to update TTS settings
class UpdateTtsSettings extends SettingsEvent {
  final bool enabled;
  final double? rate;
  final double? pitch;
  final double? volume;
  final String? language;
  final String? voice;

  const UpdateTtsSettings({
    required this.enabled,
    this.rate,
    this.pitch,
    this.volume,
    this.language,
    this.voice,
  });

  @override
  List<Object?> get props => [enabled, rate, pitch, volume, language, voice];

  @override
  String toString() => 'UpdateTtsSettings { '
      'enabled: $enabled, '
      'rate: $rate, '
      'pitch: $pitch, '
      'volume: $volume, '
      'language: $language, '
      'voice: $voice '
      '}';
}

/// Event to update fake call settings
class UpdateFakeCallSettings extends SettingsEvent {
  final bool enabled;
  final String? defaultCallerName;
  final String? defaultCallerPhoto;
  final String? ringtone;

  const UpdateFakeCallSettings({
    required this.enabled,
    this.defaultCallerName,
    this.defaultCallerPhoto,
    this.ringtone,
  });

  @override
  List<Object?> get props => [
    enabled,
    defaultCallerName,
    defaultCallerPhoto,
    ringtone,
  ];

  @override
  String toString() => 'UpdateFakeCallSettings { '
      'enabled: $enabled, '
      'caller: $defaultCallerName '
      '}';
}

/// Event to update a single setting by key
class UpdateSingleSetting extends SettingsEvent {
  final String key;
  final dynamic value;

  const UpdateSingleSetting({
    required this.key,
    required this.value,
  });

  @override
  List<Object?> get props => [key, value];

  @override
  String toString() => 'UpdateSingleSetting { key: $key, value: $value }';
}

/// Event to toggle a boolean setting
class ToggleSetting extends SettingsEvent {
  final String settingKey;

  const ToggleSetting(this.settingKey);

  @override
  List<Object?> get props => [settingKey];

  @override
  String toString() => 'ToggleSetting { key: $settingKey }';
}

/// Event to reset settings to default values
class ResetSettings extends SettingsEvent {
  final bool resetAll;
  final List<String>? specificKeys; // Reset only specific settings

  const ResetSettings({
    this.resetAll = true,
    this.specificKeys,
  });

  @override
  List<Object?> get props => [resetAll, specificKeys];

  @override
  String toString() => 'ResetSettings { '
      'resetAll: $resetAll, '
      'keys: $specificKeys '
      '}';
}

/// Event to sync settings across devices
class SyncSettings extends SettingsEvent {
  final bool forceSync;

  const SyncSettings({this.forceSync = false});

  @override
  List<Object?> get props => [forceSync];

  @override
  String toString() => 'SyncSettings { forceSync: $forceSync }';
}

/// Event to import settings from a file/JSON
class ImportSettings extends SettingsEvent {
  final String jsonData;
  final bool mergeWithExisting;

  const ImportSettings({
    required this.jsonData,
    this.mergeWithExisting = false,
  });

  @override
  List<Object?> get props => [jsonData, mergeWithExisting];

  @override
  String toString() => 'ImportSettings { merge: $mergeWithExisting }';
}

/// Event to export settings to a file/JSON
class ExportSettings extends SettingsEvent {
  final String? filePath;

  const ExportSettings({this.filePath});

  @override
  List<Object?> get props => [filePath];

  @override
  String toString() => 'ExportSettings { path: $filePath }';
}

/// Event to clear all app data and settings
class ClearAllData extends SettingsEvent {
  final bool includeCache;
  final bool includeUserData;

  const ClearAllData({
    this.includeCache = true,
    this.includeUserData = false,
  });

  @override
  List<Object?> get props => [includeCache, includeUserData];

  @override
  String toString() => 'ClearAllData { '
      'cache: $includeCache, '
      'userData: $includeUserData '
      '}';
}

/// Event to update language/locale settings
class UpdateLanguageSettings extends SettingsEvent {
  final String languageCode;
  final String? countryCode;

  const UpdateLanguageSettings({
    required this.languageCode,
    this.countryCode,
  });

  @override
  List<Object?> get props => [languageCode, countryCode];

  @override
  String toString() => 'UpdateLanguageSettings { '
      'language: $languageCode, '
      'country: $countryCode '
      '}';
}

/// Event to update privacy settings
class UpdatePrivacySettings extends SettingsEvent {
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final bool dataSharingEnabled;

  const UpdatePrivacySettings({
    required this.analyticsEnabled,
    required this.crashReportingEnabled,
    required this.dataSharingEnabled,
  });

  @override
  List<Object?> get props => [
    analyticsEnabled,
    crashReportingEnabled,
    dataSharingEnabled,
  ];

  @override
  String toString() => 'UpdatePrivacySettings { '
      'analytics: $analyticsEnabled, '
      'crashReporting: $crashReportingEnabled, '
      'dataSharing: $dataSharingEnabled '
      '}';
}

/// Event to update backup settings
class UpdateBackupSettings extends SettingsEvent {
  final bool autoBackupEnabled;
  final String? backupFrequency; // 'daily', 'weekly', 'monthly'
  final bool includeTasksInBackup;
  final bool wifiOnlyBackup;

  const UpdateBackupSettings({
    required this.autoBackupEnabled,
    this.backupFrequency,
    this.includeTasksInBackup = true,
    this.wifiOnlyBackup = true,
  });

  @override
  List<Object?> get props => [
    autoBackupEnabled,
    backupFrequency,
    includeTasksInBackup,
    wifiOnlyBackup,
  ];

  @override
  String toString() => 'UpdateBackupSettings { '
      'enabled: $autoBackupEnabled, '
      'frequency: $backupFrequency '
      '}';
}

/// Event to validate settings before saving
class ValidateSettings extends SettingsEvent {
  final SettingsModel settings;

  const ValidateSettings(this.settings);

  @override
  List<Object?> get props => [settings];

  @override
  String toString() => 'ValidateSettings';
}

/// Event to refresh settings from remote source
class RefreshSettingsFromRemote extends SettingsEvent {
  const RefreshSettingsFromRemote();

  @override
  String toString() => 'RefreshSettingsFromRemote';
}