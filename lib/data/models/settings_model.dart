// lib/data/models/settings_model.dart ✅ 100% FIXED
import 'package:equatable/equatable.dart';

class SettingsModel extends Equatable {
  final String appLanguage;
  final String? countryCode;
  final bool firstTimeUser;
  final DateTime? lastUpdated;
  final String themeMode;
  final String? primaryColor;
  final bool useMaterialYou;
  final String fontFamily;
  final double fontSize;
  final bool notificationsEnabled;
  final bool taskReminders;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String? notificationSound;
  final int reminderMinutesBefore;
  final bool showNotificationBadge;
  final bool ttsEnabled;
  final double ttsRate;
  final double ttsPitch;
  final double ttsVolume;
  final String ttsLanguage;
  final String? ttsVoice;
  final bool ttsAutoRead;
  final bool readTitle;
  final bool readDescription;
  final String scheduleInterval;
  final bool fakeCallEnabled;
  final String? defaultCallerName;
  final String? defaultCallerPhoto;
  final String? fakeCallRingtone;
  final int fakeCallDelaySeconds;
  final bool fakeCallVibrate;
  final bool voiceInputEnabled;
  final String voiceLanguage;
  final bool continuousListening;
  final double voiceSensitivity;
  final String defaultTaskStatus;
  final bool autoScheduleTasks;
  final int defaultTaskDuration;
  final bool showCompletedTasks;
  final String taskSortBy;
  final bool groupTasksByDate;
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final bool dataSharingEnabled;
  final bool requireBiometric;
  final bool requirePinCode;
  final String? pinCode;
  final bool autoBackupEnabled;
  final String backupFrequency;
  final bool backupToCloud;
  final bool wifiOnlyBackup;
  final bool includeTasksInBackup;
  final bool includeSettingsInBackup;
  final DateTime? lastBackupDate;
  final bool show24HourTime;
  final String dateFormat;
  final bool showWeekNumbers;
  final int firstDayOfWeek;
  final bool compactView;
  final bool developerMode;
  final bool showDebugInfo;
  final int maxCacheSize;
  final bool offlineMode;
  final int syncIntervalMinutes;

  const SettingsModel({
    this.appLanguage = 'en',
    this.countryCode,
    this.firstTimeUser = true,
    this.lastUpdated,
    this.themeMode = 'light',
    this.primaryColor,
    this.useMaterialYou = true,
    this.fontFamily = 'default',
    this.fontSize = 1.0,
    this.notificationsEnabled = true,
    this.taskReminders = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationSound,
    this.reminderMinutesBefore = 15,
    this.showNotificationBadge = true,
    this.ttsEnabled = false,
    this.ttsRate = 0.5,
    this.ttsPitch = 1.0,
    this.ttsVolume = 1.0,
    this.ttsLanguage = 'en-US',
    this.ttsVoice,
    this.ttsAutoRead = false,
    this.readTitle = true,
    this.readDescription = true,
    this.scheduleInterval = 'Every 15 minutes',
    this.fakeCallEnabled = false,
    this.defaultCallerName = 'Unknown',
    this.defaultCallerPhoto,
    this.fakeCallRingtone,
    this.fakeCallDelaySeconds = 5,
    this.fakeCallVibrate = true,
    this.voiceInputEnabled = true,
    this.voiceLanguage = 'en-US',
    this.continuousListening = false,
    this.voiceSensitivity = 0.5,
    this.defaultTaskStatus = 'scheduled',
    this.autoScheduleTasks = false,
    this.defaultTaskDuration = 30,
    this.showCompletedTasks = true,
    this.taskSortBy = 'date',
    this.groupTasksByDate = true,
    this.analyticsEnabled = false,
    this.crashReportingEnabled = true,
    this.dataSharingEnabled = false,
    this.requireBiometric = false,
    this.requirePinCode = false,
    this.pinCode,
    this.autoBackupEnabled = false,
    this.backupFrequency = 'weekly',
    this.backupToCloud = false,
    this.wifiOnlyBackup = true,
    this.includeTasksInBackup = true,
    this.includeSettingsInBackup = true,
    this.lastBackupDate,
    this.show24HourTime = false,
    this.dateFormat = 'MM/DD/YYYY',
    this.showWeekNumbers = false,
    this.firstDayOfWeek = 0,
    this.compactView = false,
    this.developerMode = false,
    this.showDebugInfo = false,
    this.maxCacheSize = 100,
    this.offlineMode = false,
    this.syncIntervalMinutes = 60,
  });

  factory SettingsModel.defaultSettings() => const SettingsModel();

  @override
  List<Object?> get props =>
      <Object?>[
        appLanguage,
        countryCode,
        firstTimeUser,
        lastUpdated,
        themeMode,
        primaryColor,
        useMaterialYou,
        fontFamily,
        fontSize,
        notificationsEnabled,
        taskReminders,
        soundEnabled,
        vibrationEnabled,
        notificationSound,
        reminderMinutesBefore,
        showNotificationBadge,
        ttsEnabled,
        ttsRate,
        ttsPitch,
        ttsVolume,
        ttsLanguage,
        ttsVoice,
        ttsAutoRead,
        readTitle,
        readDescription,
        scheduleInterval,
        fakeCallEnabled,
        defaultCallerName,
        defaultCallerPhoto,
        fakeCallRingtone,
        fakeCallDelaySeconds,
        fakeCallVibrate,
        voiceInputEnabled,
        voiceLanguage,
        continuousListening,
        voiceSensitivity,
        defaultTaskStatus,
        autoScheduleTasks,
        defaultTaskDuration,
        showCompletedTasks,
        taskSortBy,
        groupTasksByDate,
        analyticsEnabled,
        crashReportingEnabled,
        dataSharingEnabled,
        requireBiometric,
        requirePinCode,
        pinCode,
        autoBackupEnabled,
        backupFrequency,
        backupToCloud,
        wifiOnlyBackup,
        includeTasksInBackup,
        includeSettingsInBackup,
        lastBackupDate,
        show24HourTime,
        dateFormat,
        showWeekNumbers,
        firstDayOfWeek,
        compactView,
        developerMode,
        showDebugInfo,
        maxCacheSize,
        offlineMode,
        syncIntervalMinutes,
      ];

  SettingsModel copyWith({
    String? appLanguage,
    String? countryCode,
    bool? firstTimeUser,
    DateTime? lastUpdated,
    String? themeMode,
    String? primaryColor,
    bool? useMaterialYou,
    String? fontFamily,
    double? fontSize,
    bool? notificationsEnabled,
    bool? taskReminders,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? notificationSound,
    int? reminderMinutesBefore,
    bool? showNotificationBadge,
    bool? ttsEnabled,
    double? ttsRate,
    double? ttsPitch,
    double? ttsVolume,
    String? ttsLanguage,
    String? ttsVoice,
    bool? ttsAutoRead,
    bool? readTitle,
    bool? readDescription,
    String? scheduleInterval,
    bool? fakeCallEnabled,
    String? defaultCallerName,
    String? defaultCallerPhoto,
    String? fakeCallRingtone,
    int? fakeCallDelaySeconds,
    bool? fakeCallVibrate,
    bool? voiceInputEnabled,
    String? voiceLanguage,
    bool? continuousListening,
    double? voiceSensitivity,
    String? defaultTaskStatus,
    bool? autoScheduleTasks,
    int? defaultTaskDuration,
    bool? showCompletedTasks,
    String? taskSortBy,
    bool? groupTasksByDate,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    bool? dataSharingEnabled,
    bool? requireBiometric,
    bool? requirePinCode,
    String? pinCode,
    bool? autoBackupEnabled,
    String? backupFrequency,
    bool? backupToCloud,
    bool? wifiOnlyBackup,
    bool? includeTasksInBackup,
    bool? includeSettingsInBackup,
    DateTime? lastBackupDate,
    bool? show24HourTime,
    String? dateFormat,
    bool? showWeekNumbers,
    int? firstDayOfWeek,
    bool? compactView,
    bool? developerMode,
    bool? showDebugInfo,
    int? maxCacheSize,
    bool? offlineMode,
    int? syncIntervalMinutes,
  }) {
    return SettingsModel(
      appLanguage: appLanguage ?? this.appLanguage,
      countryCode: countryCode ?? this.countryCode,
      firstTimeUser: firstTimeUser ?? this.firstTimeUser,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      useMaterialYou: useMaterialYou ?? this.useMaterialYou,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      taskReminders: taskReminders ?? this.taskReminders,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationSound: notificationSound ?? this.notificationSound,
      reminderMinutesBefore: reminderMinutesBefore ??
          this.reminderMinutesBefore,
      showNotificationBadge: showNotificationBadge ??
          this.showNotificationBadge,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsAutoRead: ttsAutoRead ?? this.ttsAutoRead,
      readTitle: readTitle ?? this.readTitle,
      readDescription: readDescription ?? this.readDescription,
      scheduleInterval: scheduleInterval ?? this.scheduleInterval,
      fakeCallEnabled: fakeCallEnabled ?? this.fakeCallEnabled,
      defaultCallerName: defaultCallerName ?? this.defaultCallerName,
      defaultCallerPhoto: defaultCallerPhoto ?? this.defaultCallerPhoto,
      fakeCallRingtone: fakeCallRingtone ?? this.fakeCallRingtone,
      fakeCallDelaySeconds: fakeCallDelaySeconds ?? this.fakeCallDelaySeconds,
      fakeCallVibrate: fakeCallVibrate ?? this.fakeCallVibrate,
      voiceInputEnabled: voiceInputEnabled ?? this.voiceInputEnabled,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      continuousListening: continuousListening ?? this.continuousListening,
      voiceSensitivity: voiceSensitivity ?? this.voiceSensitivity,
      defaultTaskStatus: defaultTaskStatus ?? this.defaultTaskStatus,
      autoScheduleTasks: autoScheduleTasks ?? this.autoScheduleTasks,
      defaultTaskDuration: defaultTaskDuration ?? this.defaultTaskDuration,
      showCompletedTasks: showCompletedTasks ?? this.showCompletedTasks,
      taskSortBy: taskSortBy ?? this.taskSortBy,
      groupTasksByDate: groupTasksByDate ?? this.groupTasksByDate,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled: crashReportingEnabled ??
          this.crashReportingEnabled,
      dataSharingEnabled: dataSharingEnabled ?? this.dataSharingEnabled,
      requireBiometric: requireBiometric ?? this.requireBiometric,
      requirePinCode: requirePinCode ?? this.requirePinCode,
      pinCode: pinCode ?? this.pinCode,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      backupToCloud: backupToCloud ?? this.backupToCloud,
      wifiOnlyBackup: wifiOnlyBackup ?? this.wifiOnlyBackup,
      includeTasksInBackup: includeTasksInBackup ?? this.includeTasksInBackup,
      includeSettingsInBackup: includeSettingsInBackup ??
          this.includeSettingsInBackup,
      lastBackupDate: lastBackupDate ?? this.lastBackupDate,
      show24HourTime: show24HourTime ?? this.show24HourTime,
      dateFormat: dateFormat ?? this.dateFormat,
      showWeekNumbers: showWeekNumbers ?? this.showWeekNumbers,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      compactView: compactView ?? this.compactView,
      developerMode: developerMode ?? this.developerMode,
      showDebugInfo: showDebugInfo ?? this.showDebugInfo,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      offlineMode: offlineMode ?? this.offlineMode,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
    );
  }

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
        'appLanguage': appLanguage,
        'countryCode': countryCode,
        'firstTimeUser': firstTimeUser,
        'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
        'themeMode': themeMode,
        'primaryColor': primaryColor,
        'useMaterialYou': useMaterialYou,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'notificationsEnabled': notificationsEnabled,
        'taskReminders': taskReminders,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'notificationSound': notificationSound,
        'reminderMinutesBefore': reminderMinutesBefore,
        'showNotificationBadge': showNotificationBadge,
        'ttsEnabled': ttsEnabled,
        'ttsRate': ttsRate,
        'ttsPitch': ttsPitch,
        'ttsVolume': ttsVolume,
        'ttsLanguage': ttsLanguage,
        'ttsVoice': ttsVoice,
        'ttsAutoRead': ttsAutoRead,
        'readTitle': readTitle,
        'readDescription': readDescription,
        'scheduleInterval': scheduleInterval,
        'fakeCallEnabled': fakeCallEnabled,
        'defaultCallerName': defaultCallerName,
        'defaultCallerPhoto': defaultCallerPhoto,
        'fakeCallRingtone': fakeCallRingtone,
        'fakeCallDelaySeconds': fakeCallDelaySeconds,
        'fakeCallVibrate': fakeCallVibrate,
        'voiceInputEnabled': voiceInputEnabled,
        'voiceLanguage': voiceLanguage,
        'continuousListening': continuousListening,
        'voiceSensitivity': voiceSensitivity,
        'defaultTaskStatus': defaultTaskStatus,
        'autoScheduleTasks': autoScheduleTasks,
        'defaultTaskDuration': defaultTaskDuration,
        'showCompletedTasks': showCompletedTasks,
        'taskSortBy': taskSortBy,
        'groupTasksByDate': groupTasksByDate,
        'analyticsEnabled': analyticsEnabled,
        'crashReportingEnabled': crashReportingEnabled,
        'dataSharingEnabled': dataSharingEnabled,
        'requireBiometric': requireBiometric,
        'requirePinCode': requirePinCode,
        'pinCode': pinCode,
        'autoBackupEnabled': autoBackupEnabled,
        'backupFrequency': backupFrequency,
        'backupToCloud': backupToCloud,
        'wifiOnlyBackup': wifiOnlyBackup,
        'includeTasksInBackup': includeTasksInBackup,
        'includeSettingsInBackup': includeSettingsInBackup,
        'lastBackupDate': lastBackupDate?.millisecondsSinceEpoch,
        'show24HourTime': show24HourTime,
        'dateFormat': dateFormat,
        'showWeekNumbers': showWeekNumbers,
        'firstDayOfWeek': firstDayOfWeek,
        'compactView': compactView,
        'developerMode': developerMode,
        'showDebugInfo': showDebugInfo,
        'maxCacheSize': maxCacheSize,
        'offlineMode': offlineMode,
        'syncIntervalMinutes': syncIntervalMinutes,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
    appLanguage: json['appLanguage'] as String? ?? 'en',
    countryCode: json['countryCode'] as String?,
    firstTimeUser: json['firstTimeUser'] as bool? ?? true,
    lastUpdated: json['lastUpdated'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int)
        : null,
    themeMode: json['themeMode'] as String? ?? 'light',
    primaryColor: json['primaryColor'] as String?,
    useMaterialYou: json['useMaterialYou'] as bool? ?? true,
    fontFamily: json['fontFamily'] as String? ?? 'default',
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 1.0,
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    taskReminders: json['taskReminders'] as bool? ?? true,
    soundEnabled: json['soundEnabled'] as bool? ?? true,
    vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    notificationSound: json['notificationSound'] as String?,
    reminderMinutesBefore:
    json['reminderMinutesBefore'] as int? ?? 15,
    showNotificationBadge:
    json['showNotificationBadge'] as bool? ?? true,
    ttsEnabled: json['ttsEnabled'] as bool? ?? false,
    ttsRate: (json['ttsRate'] as num?)?.toDouble() ?? 0.5,
    ttsPitch: (json['ttsPitch'] as num?)?.toDouble() ?? 1.0,
    ttsVolume: (json['ttsVolume'] as num?)?.toDouble() ?? 1.0,
    ttsLanguage: json['ttsLanguage'] as String? ?? 'en-US',
    ttsVoice: json['ttsVoice'] as String?,
    ttsAutoRead: json['ttsAutoRead'] as bool? ?? false,
    readTitle: json['readTitle'] as bool? ?? true,
    readDescription: json['readDescription'] as bool? ?? true,
    scheduleInterval:
    json['scheduleInterval'] as String? ?? 'Every 15 minutes',
    fakeCallEnabled: json['fakeCallEnabled'] as bool? ?? false,
    defaultCallerName:
    json['defaultCallerName'] as String? ?? 'Unknown',
    defaultCallerPhoto: json['defaultCallerPhoto'] as String?,
    fakeCallRingtone: json['fakeCallRingtone'] as String?,
    fakeCallDelaySeconds:
    json['fakeCallDelaySeconds'] as int? ?? 5,
    fakeCallVibrate: json['fakeCallVibrate'] as bool? ?? true,
    voiceInputEnabled:
    json['voiceInputEnabled'] as bool? ?? true,
    voiceLanguage:
    json['voiceLanguage'] as String? ?? 'en-US',
    continuousListening:
    json['continuousListening'] as bool? ?? false,
    voiceSensitivity:
    (json['voiceSensitivity'] as num?)?.toDouble() ?? 0.5,
    defaultTaskStatus:
    json['defaultTaskStatus'] as String? ?? 'scheduled',
    autoScheduleTasks:
    json['autoScheduleTasks'] as bool? ?? false,
    defaultTaskDuration:
    json['defaultTaskDuration'] as int? ?? 30,
    showCompletedTasks:
    json['showCompletedTasks'] as bool? ?? true,
    taskSortBy: json['taskSortBy'] as String? ?? 'date',
    groupTasksByDate:
    json['groupTasksByDate'] as bool? ?? true,
    analyticsEnabled:
    json['analyticsEnabled'] as bool? ?? false,
    crashReportingEnabled:
    json['crashReportingEnabled'] as bool? ?? true,
    dataSharingEnabled:
    json['dataSharingEnabled'] as bool? ?? false,
    requireBiometric:
    json['requireBiometric'] as bool? ?? false,
    requirePinCode:
    json['requirePinCode'] as bool? ?? false,
    pinCode: json['pinCode'] as String?,
    autoBackupEnabled:
    json['autoBackupEnabled'] as bool? ?? false,
    backupFrequency:
    json['backupFrequency'] as String? ?? 'weekly',
    backupToCloud:
    json['backupToCloud'] as bool? ?? false,
    wifiOnlyBackup:
    json['wifiOnlyBackup'] as bool? ?? true,
    includeTasksInBackup:
    json['includeTasksInBackup'] as bool? ?? true,
    includeSettingsInBackup:
    json['includeSettingsInBackup'] as bool? ?? true,
    lastBackupDate: json['lastBackupDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
      json['lastBackupDate'] as int,
    )
        : null,
    show24HourTime:
    json['show24HourTime'] as bool? ?? false,
    dateFormat:
    json['dateFormat'] as String? ?? 'MM/DD/YYYY',
    showWeekNumbers:
    json['showWeekNumbers'] as bool? ?? false,
    firstDayOfWeek:
    json['firstDayOfWeek'] as int? ?? 0,
    compactView: json['compactView'] as bool? ?? false,
    developerMode:
    json['developerMode'] as bool? ?? false,
    showDebugInfo:
    json['showDebugInfo'] as bool? ?? false,
    maxCacheSize:
    json['maxCacheSize'] as int? ?? 100,
    offlineMode:
    json['offlineMode'] as bool? ?? false,
    syncIntervalMinutes:
    json['syncIntervalMinutes'] as int? ?? 60,
  );

  /// Overall validation for the full settings object
  bool validateAll() {
    if (appLanguage.isEmpty) return false;
    if (fontSize <= 0) return false;
    if (reminderMinutesBefore < 0) return false;
    if (maxCacheSize <= 0) return false;

    // Reuse TTS validation rules
    if (!validateTtsSettings()) return false;

    return true;
  }

  /// Validation specifically for TTS-related values
  bool validateTtsSettings() {
    if (!ttsEnabled) return true; // if disabled, treat as valid

    if (ttsLanguage.isEmpty) return false;
    if (ttsRate <= 0 || ttsRate > 2.0) return false;
    if (ttsPitch <= 0 || ttsPitch > 2.0) return false;
    if (ttsVolume <= 0 || ttsVolume > 1.0) return false;

    return true;
  }
}
