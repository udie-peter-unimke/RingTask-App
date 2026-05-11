import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/blocs/settings/settings_event.dart';
import 'package:ringtask/blocs/settings/settings_state.dart';
import 'package:ringtask/data/models/settings_model.dart';

import 'package:ringtask/repositories/settings_repository.dart';

/// BLoC responsible for managing app settings
/// Handles loading, updating, syncing, and resetting settings
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _settingsRepository;

  SettingsBloc({
    required SettingsRepository settingsRepository,
  })  : _settingsRepository = settingsRepository,
        super(const SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateSettings>(_onUpdateSettings);
    on<UpdateNotificationSettings>(_onUpdateNotificationSettings);
    on<UpdateThemeSettings>(_onUpdateThemeSettings);
    on<UpdateTtsSettings>(_onUpdateTtsSettings);
    on<UpdateFakeCallSettings>(_onUpdateFakeCallSettings);
    on<UpdateSingleSetting>(_onUpdateSingleSetting);
    on<ToggleSetting>(_onToggleSetting);
    on<ResetSettings>(_onResetSettings);
    on<SyncSettings>(_onSyncSettings);
    on<ImportSettings>(_onImportSettings);
    on<ExportSettings>(_onExportSettings);
    on<ClearAllData>(_onClearAllData);
    on<UpdateLanguageSettings>(_onUpdateLanguageSettings);
    on<UpdatePrivacySettings>(_onUpdatePrivacySettings);
    on<UpdateBackupSettings>(_onUpdateBackupSettings);
    on<ValidateSettings>(_onValidateSettings);
    on<RefreshSettingsFromRemote>(_onRefreshSettingsFromRemote);
  }

  /// Load settings from storage
  Future<void> _onLoadSettings(
      LoadSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      emit(const SettingsLoading());

      final settings = await _settingsRepository.getSettings();

      emit(SettingsLoaded(settings));
      developer.log('Settings loaded successfully', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );
      emit(SettingsError(
        message: 'Failed to load settings: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update entire settings object
  Future<void> _onUpdateSettings(
      UpdateSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      emit(SettingsUpdating(
        currentSettings: currentSettings,
        pendingSettings: event.settings,
      ));

      // Validate settings before saving
      if (!event.settings.validateAll()) {
        emit(SettingsError(
          message: 'Invalid settings values',
          lastKnownSettings: currentSettings,
        ));
        return;
      }

      await _settingsRepository.updateSettings(event.settings);

      if (event.showSuccessMessage) {
        emit(SettingsUpdateSuccess(
          settings: event.settings,
          successMessage: 'Settings saved successfully',
        ));
      } else {
        emit(SettingsLoaded(event.settings));
      }

      developer.log('Settings updated successfully', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update settings: ${e.toString()}',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Update notification settings only
  Future<void> _onUpdateNotificationSettings(
      UpdateNotificationSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      final updatedSettings = currentSettings.copyWith(
        notificationsEnabled: event.enabled,
        notificationSound: event.soundPath,
        vibrationEnabled: event.vibrate,
      );

      emit(SettingsUpdating(
        currentSettings: currentSettings,
        pendingSettings: updatedSettings,
      ));

      await _settingsRepository.updateSettings(updatedSettings);

      emit(SettingsUpdateSuccess(
        settings: updatedSettings,
        successMessage: 'Notification settings updated',
      ));

      developer.log('Notification settings updated', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update notification settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update notification settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Update theme settings
  Future<void> _onUpdateThemeSettings(
      UpdateThemeSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      final updatedSettings = currentSettings.copyWith(
        themeMode: event.themeMode,
        primaryColor: event.primaryColor,
      );

      await _settingsRepository.updateSettings(updatedSettings);

      emit(SettingsUpdateSuccess(
        settings: updatedSettings,
        successMessage: 'Theme updated',
      ));

      developer.log('Theme settings updated', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update theme settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update theme',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Update TTS settings
  Future<void> _onUpdateTtsSettings(
      UpdateTtsSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      final updatedSettings = currentSettings.copyWith(
        ttsEnabled: event.enabled,
        ttsRate: event.rate,
        ttsPitch: event.pitch,
        ttsVolume: event.volume,
        ttsLanguage: event.language,
        ttsVoice: event.voice,
      );

      // Validate TTS settings
      if (!updatedSettings.validateTtsSettings()) {
        emit(SettingsError(
          message: 'Invalid TTS settings values',
          lastKnownSettings: currentSettings,
        ));
        return;
      }

      await _settingsRepository.updateSettings(updatedSettings);

      emit(SettingsUpdateSuccess(
        settings: updatedSettings,
        successMessage: 'Text-to-Speech settings updated',
      ));

      developer.log('TTS settings updated', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update TTS settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update TTS settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Update fake call settings
  Future<void> _onUpdateFakeCallSettings(
      UpdateFakeCallSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      final updatedSettings = currentSettings.copyWith(
        fakeCallEnabled: event.enabled,
        defaultCallerName: event.defaultCallerName,
        defaultCallerPhoto: event.defaultCallerPhoto,
        fakeCallRingtone: event.ringtone,
      );

      await _settingsRepository.updateSettings(updatedSettings);

      emit(SettingsUpdateSuccess(
        settings: updatedSettings,
        successMessage: 'Fake call settings updated',
      ));

      developer.log('Fake call settings updated', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update fake call settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update fake call settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Update a single setting by key
  Future<void> _onUpdateSingleSetting(
      UpdateSingleSetting event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      await _settingsRepository.updateSingleSetting(event.key, event.value);
      final updatedSettings = await _settingsRepository.getSettings();

      emit(SettingsLoaded(updatedSettings));

      developer.log('Single setting updated: ${event.key}', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update single setting: ${event.key}',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update setting',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Toggle a boolean setting
  Future<void> _onToggleSetting(
      ToggleSetting event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      await _settingsRepository.toggleSetting(event.settingKey);
      final updatedSettings = await _settingsRepository.getSettings();

      emit(SettingsLoaded(updatedSettings));

      developer.log('Setting toggled: ${event.settingKey}', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to toggle setting: ${event.settingKey}',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to toggle setting',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Reset settings to defaults
  Future<void> _onResetSettings(
      ResetSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      emit(SettingsResetting(currentSettings: currentSettings));

      final resetSettings = await _settingsRepository.resetSettings(
        specificKeys: event.specificKeys,
      );

      emit(SettingsResetSuccess(defaultSettings: resetSettings));

      developer.log(
        event.resetAll ? 'All settings reset' : 'Specific settings reset',
        name: 'SettingsBloc',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to reset settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to reset settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Sync settings with remote
  Future<void> _onSyncSettings(
      SyncSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      emit(SettingsSyncing(currentSettings: currentSettings));

      final syncedSettings = await _settingsRepository.syncWithRemote();

      emit(SettingsSyncSuccess(syncedSettings: syncedSettings));

      developer.log('Settings synced successfully', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to sync settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to sync settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Import settings from JSON
  Future<void> _onImportSettings(
      ImportSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      emit(SettingsUpdating(
        currentSettings: currentSettings,
        pendingSettings: currentSettings, // Placeholder
      ));

      final importedSettings = await _settingsRepository.importSettings(
        event.jsonData,
        merge: event.mergeWithExisting,
      );

      emit(SettingsUpdateSuccess(
        settings: importedSettings,
        successMessage: event.mergeWithExisting
            ? 'Settings imported and merged'
            : 'Settings imported',
      ));

      developer.log('Settings imported successfully', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to import settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to import settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Export settings to JSON
  Future<void> _onExportSettings(
      ExportSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final _ = await _settingsRepository.exportSettings();

      // Note: Actual file writing would be handled by the UI layer
      // This just prepares the data

      developer.log('Settings exported successfully', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to export settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      emit(SettingsError(
        message: 'Failed to export settings',
        error: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Clear all data
  Future<void> _onClearAllData(
      ClearAllData event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      emit(const SettingsLoading());

      await _settingsRepository.clearAllData();

      emit(const SettingsInitial());

      developer.log('All data cleared', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to clear data',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      emit(SettingsError(
        message: 'Failed to clear data',
        error: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update language settings
  Future<void> _onUpdateLanguageSettings(
      UpdateLanguageSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      final updatedSettings = currentSettings.copyWith(
        appLanguage: event.languageCode,
        countryCode: event.countryCode,
      );

      await _settingsRepository.updateSettings(updatedSettings);

      emit(SettingsUpdateSuccess(
        settings: updatedSettings,
        successMessage: 'Language updated',
      ));

      developer.log('Language settings updated', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update language settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update language',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Update privacy settings
  Future<void> _onUpdatePrivacySettings(
      UpdatePrivacySettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      final updatedSettings = currentSettings.copyWith(
        analyticsEnabled: event.analyticsEnabled,
        crashReportingEnabled: event.crashReportingEnabled,
        dataSharingEnabled: event.dataSharingEnabled,
      );

      await _settingsRepository.updateSettings(updatedSettings);

      emit(SettingsUpdateSuccess(
        settings: updatedSettings,
        successMessage: 'Privacy settings updated',
      ));

      developer.log('Privacy settings updated', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update privacy settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update privacy settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Update backup settings
  Future<void> _onUpdateBackupSettings(
      UpdateBackupSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      final updatedSettings = currentSettings.copyWith(
        autoBackupEnabled: event.autoBackupEnabled,
        backupFrequency: event.backupFrequency,
        includeTasksInBackup: event.includeTasksInBackup,
        wifiOnlyBackup: event.wifiOnlyBackup,
      );

      await _settingsRepository.updateSettings(updatedSettings);

      emit(SettingsUpdateSuccess(
        settings: updatedSettings,
        successMessage: 'Backup settings updated',
      ));

      developer.log('Backup settings updated', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update backup settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to update backup settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Validate settings
  Future<void> _onValidateSettings(
      ValidateSettings event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final isValid = await _settingsRepository.validateSettings(event.settings);

      if (!isValid) {
        emit(SettingsError(
          message: 'Settings validation failed',
          lastKnownSettings: event.settings,
        ));
      }

      developer.log('Settings validated: $isValid', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to validate settings',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      emit(SettingsError(
        message: 'Failed to validate settings',
        error: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Refresh settings from remote
  Future<void> _onRefreshSettingsFromRemote(
      RefreshSettingsFromRemote event,
      Emitter<SettingsState> emit,
      ) async {
    try {
      final currentSettings = await _getCurrentSettings();

      emit(SettingsSyncing(currentSettings: currentSettings));

      final refreshedSettings = await _settingsRepository.syncWithRemote();

      emit(SettingsSyncSuccess(syncedSettings: refreshedSettings));

      developer.log('Settings refreshed from remote', name: 'SettingsBloc');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to refresh settings from remote',
        name: 'SettingsBloc',
        error: e,
        stackTrace: stackTrace,
      );

      final lastKnown = await _safeGetSettings();
      emit(SettingsError(
        message: 'Failed to refresh settings',
        error: e,
        stackTrace: stackTrace,
        lastKnownSettings: lastKnown,
      ));
    }
  }

  /// Helper: Get current settings from state or repository
  Future<SettingsModel> _getCurrentSettings() async {
    if (state is SettingsLoaded) {
      return (state as SettingsLoaded).settings;
    } else if (state is SettingsUpdateSuccess) {
      return (state as SettingsUpdateSuccess).settings;
    } else if (state is SettingsSyncSuccess) {
      return (state as SettingsSyncSuccess).syncedSettings;
    } else if (state is SettingsResetSuccess) {
      return (state as SettingsResetSuccess).defaultSettings;
    }

    return await _settingsRepository.getSettings();
  }

  /// Helper: Safely get settings without throwing
  Future<SettingsModel?> _safeGetSettings() async {
    try {
      return await _settingsRepository.getSettings();
    } catch (e) {
      developer.log(
        'Failed to get settings for error recovery',
        name: 'SettingsBloc',
        error: e,
      );
      return null;
    }
  }

  @override
  Future<void> close() {
    developer.log('SettingsBloc closed', name: 'SettingsBloc');
    return super.close();
  }
}