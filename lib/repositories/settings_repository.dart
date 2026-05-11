// lib/repositories/settings_repository.dart
import 'dart:convert';
import 'package:ringtask/data/datasources/local/cache_manager.dart'; // Add CacheManager import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringtask/data/models/settings_model.dart';

class SettingsRepository {
  static const String _keySettings = 'app_settings_v2'; // Fallback key for SharedPreferences
  final CacheManager _cacheManager; // CacheManager dependency

  SettingsRepository(this._cacheManager);

  // ──────────────────────────────────────────────────────────────
  // 1. Get current settings (CACHE FIRST → SharedPrefs fallback)
  // ──────────────────────────────────────────────────────────────
  Future<SettingsModel> getSettings() async {
    try {
      // 1. Try CacheManager first (fastest)
      final cachedSettings = await _cacheManager.getCachedSettings();
      if (cachedSettings != null) {
        return cachedSettings;
      }
    } catch (e) {
      // Cache error → continue to SharedPreferences
    }

    // 2. Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keySettings);

    if (jsonString == null || jsonString.isEmpty) {
      // First launch → return defaults + migrate
      final defaults = SettingsModel.defaultSettings();
      await _migrateOldKeysIfNeeded(defaults);
      await _cacheManager.cacheSettings(defaults); // Cache defaults
      return defaults;
    }

    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      final settings = SettingsModel.fromJson(json);
      await _cacheManager.cacheSettings(settings); // Cache valid settings
      return settings;
    } catch (e) {
      // Corrupted JSON → reset to defaults
      final defaults = SettingsModel.defaultSettings();
      await updateSettings(defaults);
      return defaults;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 2. Save entire settings object (update both cache & SharedPrefs)
  // ──────────────────────────────────────────────────────────────
  Future<void> updateSettings(SettingsModel settings) async {
    // Update CacheManager (fast access)
    await _cacheManager.cacheSettings(settings);

    // Persist to SharedPreferences (durable storage)
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_keySettings, jsonString);
  }

  // ──────────────────────────────────────────────────────────────
  // 3. Update single field (cache + SharedPrefs)
  // ──────────────────────────────────────────────────────────────
  Future<void> updateSingleSetting(String key, dynamic value) async {
    final settings = await getSettings();
    final updated = settings.copyWithDynamic(key, value);
    await updateSettings(updated);
  }

  // ──────────────────────────────────────────────────────────────
  // 4. Toggle boolean setting
  // ──────────────────────────────────────────────────────────────
  Future<void> toggleSetting(String key) async {
    final settings = await getSettings();
    final current = settings.toJson()[key];
    if (current is bool) {
      final updated = settings.copyWithDynamic(key, !current);
      await updateSettings(updated);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 5. Reset to defaults (cache + SharedPrefs)
  // ──────────────────────────────────────────────────────────────
  Future<SettingsModel> resetSettings({List<String>? specificKeys}) async {
    final defaults = SettingsModel.defaultSettings();

    if (specificKeys == null || specificKeys.isEmpty) {
      await updateSettings(defaults);
      return defaults;
    }

    final current = await getSettings();
    var updated = current;
    for (final key in specificKeys) {
      final defaultValue = defaults.toJson()[key];
      updated = updated.copyWithDynamic(key, defaultValue);
    }
    await updateSettings(updated);
    return updated;
  }

  // ──────────────────────────────────────────────────────────────
  // 6. Sync with remote (CacheManager → Remote → Cache)
  // ──────────────────────────────────────────────────────────────
  Future<SettingsModel> syncWithRemote() async {
    // TODO: Implement Cloud Firestore sync
    // When implemented: remote → cacheSettings → return
    return await getSettings();
  }

  // ──────────────────────────────────────────────────────────────
  // 7. Import from JSON string
  // ──────────────────────────────────────────────────────────────
  Future<SettingsModel> importSettings(String jsonData, {bool merge = false}) async {
    final importedJson = jsonDecode(jsonData) as Map<String, dynamic>;
    final imported = SettingsModel.fromJson(importedJson);

    if (!merge) {
      await updateSettings(imported);
      return imported;
    }

    final current = await getSettings();
    final merged = current.mergeWith(imported);
    await updateSettings(merged);
    return merged;
  }

  // ──────────────────────────────────────────────────────────────
  // 8. Export current settings
  // ──────────────────────────────────────────────────────────────
  Future<String> exportSettings() async {
    final settings = await getSettings();
    return jsonEncode(settings.toJson());
  }

  // ──────────────────────────────────────────────────────────────
  // 9. Clear all data (CacheManager + SharedPreferences)
  // ──────────────────────────────────────────────────────────────
  Future<void> clearAllData() async {
    await _cacheManager.clearCache(); // Clear CacheManager
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ──────────────────────────────────────────────────────────────
  // 10. Validate settings structure
  // ──────────────────────────────────────────────────────────────
  Future<bool> validateSettings(SettingsModel settings) async {
    try {
      settings.validateAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Migrate old individual keys → new JSON format (one-time)
  // ──────────────────────────────────────────────────────────────
  Future<void> _migrateOldKeysIfNeeded(SettingsModel defaults) async {
    final prefs = await SharedPreferences.getInstance();

    bool hasOldKeys = false;
    final Map<String, dynamic> oldValues = {};

    if (prefs.containsKey('dark_mode')) {
      hasOldKeys = true;
      oldValues['themeMode'] = prefs.getBool('dark_mode')! ? 'dark' : 'light';
    }
    if (prefs.containsKey('language_code')) {
      hasOldKeys = true;
      oldValues['appLanguage'] = prefs.getString('language_code');
    }
    if (prefs.containsKey('enable_tts')) {
      hasOldKeys = true;
      oldValues['ttsEnabled'] = prefs.getBool('enable_tts');
    }

    if (hasOldKeys) {
      final migrated = defaults.copyWithDynamicMap(oldValues);
      await updateSettings(migrated);
      await prefs.remove('dark_mode');
      await prefs.remove('language_code');
      await prefs.remove('enable_tts');
    }
  }
}

// Extension remains unchanged
extension SettingsModelX on SettingsModel {
  SettingsModel copyWithDynamic(String key, dynamic value) {
    final json = toJson()..[key] = value;
    return SettingsModel.fromJson(json);
  }

  SettingsModel copyWithDynamicMap(Map<String, dynamic> updates) {
    final json = toJson()..addAll(updates);
    return SettingsModel.fromJson(json);
  }

  SettingsModel mergeWith(SettingsModel other) {
    return SettingsModel.fromJson(toJson()..addAll(other.toJson()));
  }
}
