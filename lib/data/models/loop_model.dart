// lib/data/models/loop_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:ringtask/utils/logger.dart';

// Add oneTime to enum
enum RecurrenceType { daily, weekly, monthly, oneTime }

RecurrenceType recurrenceFromString(String s) {
  switch (s) {
    case 'weekly':
      return RecurrenceType.weekly;
    case 'monthly':
      return RecurrenceType.monthly;
    case 'one_time':
      return RecurrenceType.oneTime;
    case 'daily':
    default:
      return RecurrenceType.daily;
  }
}

String recurrenceToString(RecurrenceType r) {
  switch (r) {
    case RecurrenceType.weekly:
      return 'weekly';
    case RecurrenceType.monthly:
      return 'monthly';
    case RecurrenceType.oneTime:
      return 'one_time';
    case RecurrenceType.daily:
      return 'daily';
  }
}

class TaskLoopItem extends Equatable {
  final String id;
  final String title;
  final String timeString;
  final String period; // 'AM' or 'PM'
  final RecurrenceType recurrence;
  final String customDaysDisplay;
  final bool isActive;
  final DateTime? updatedAt;
  final List<int> weekdays;      // 1 = Monday, ..., 7 = Sunday (for weekly recurrence)
  final DateTime? specificDate;  // for one-time tasks (or monthly specific date)

  const TaskLoopItem({
    required this.id,
    required this.title,
    required this.timeString,
    required this.period,
    required this.recurrence,
    required this.customDaysDisplay,
    required this.isActive,
    this.updatedAt, required this.weekdays, this.specificDate,
  });

  // ---------------------------------------------------------------------------
  // Firestore deserialization
  // ---------------------------------------------------------------------------

  factory TaskLoopItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    // read weekdays: expect a list of numbers (ints)
    List<int> weekdays = [];
    if (data['weekdays'] is List) {
      try {
        weekdays = (data['weekdays'] as List).whereType<num>().map((n) => n.toInt()).where((i) => i >= 1 && i <= 7).toList();
      } catch (_) { weekdays = []; }
    }

    DateTime? specificDate;
    if (data['specificDate'] is String) {
      specificDate = DateTime.tryParse(data['specificDate'] as String);
    } else if (data['specificDate'] is Timestamp) {
      specificDate = (data['specificDate'] as Timestamp).toDate();
    }

    return TaskLoopItem(
      id: doc.id,
      title: _safeString(data['title'], 'Untitled'),
      timeString: _safeTimeString(data['timeString'], doc.id),
      period: _safePeriod(data['period'], doc.id),
      recurrence: recurrenceFromString(_safeString(data['recurrence'], 'daily')),
      customDaysDisplay: _safeString(data['customDaysDisplay'], 'Every Day'),
      weekdays: weekdays,
      specificDate: specificDate,
      isActive: _safeBool(data['isActive'], fallback: true),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'timeString': timeString,
      'period': period,
      'recurrence': recurrenceToString(recurrence),
      'customDaysDisplay': customDaysDisplay,
      'weekdays': weekdays, // list of ints
      'specificDate': specificDate?.toIso8601String(),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ---------------------------------------------------------------------------
  // Local cache serialization (JSON)
  // ---------------------------------------------------------------------------

  /// Deserialises a [TaskLoopItem] from a plain JSON map as stored in the
  /// local SharedPreferences cache. Applies the same field coercion as
  /// [fromDoc] so a corrupt cached value never reaches split(':') downstream.
  factory TaskLoopItem.fromJson(Map<String, dynamic> json) {
    final contextId = json['id'] is String ? json['id'] as String : 'unknown';

    List<int> weekdays = [];
    if (json['weekdays'] is List) {
      try {
        weekdays = (json['weekdays'] as List)
            .whereType<num>()
            .map((n) => n.toInt())
            .where((i) => i >= 1 && i <= 7)
            .toList();
      } catch (_) {
        weekdays = [];
      }
    }

    DateTime? specificDate;
    if (json['specificDate'] is String) {
      specificDate = DateTime.tryParse(json['specificDate'] as String);
    }

    return TaskLoopItem(
      id: json['id'] is String ? json['id'] as String : '',
      title: _safeString(json['title'], 'Untitled'),
      timeString: _safeTimeString(json['timeString'], contextId),
      period: _safePeriod(json['period'], contextId),
      recurrence: recurrenceFromString(_safeString(json['recurrence'], 'daily')),
      customDaysDisplay: _safeString(json['customDaysDisplay'], 'Every Day'),
      isActive: _safeBool(json['isActive'], fallback: true),
      weekdays: weekdays,
      specificDate: specificDate,
      // tryParse (not parse) — a malformed ISO string returns null instead of
      // throwing FormatException and poisoning the whole cache read.
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Serialises this [TaskLoopItem] to a plain JSON map for local cache
  /// storage. Includes [id] (unlike [toMap], which omits it for Firestore
  /// writes where the id lives in the document path, not the document body).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'timeString': timeString,
      'period': period,
      'recurrence': recurrenceToString(recurrence),
      'customDaysDisplay': customDaysDisplay,
      'isActive': isActive,
      'weekdays': weekdays,
      'specificDate': specificDate?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  TaskLoopItem copyWith({
    String? id,
    String? title,
    String? timeString,
    String? period,
    RecurrenceType? recurrence,
    String? customDaysDisplay,
    bool? isActive,
    DateTime? updatedAt,
    List<int>? weekdays,
    DateTime? specificDate,
  }) {
    return TaskLoopItem(
      id: id ?? this.id,
      title: title ?? this.title,
      timeString: timeString ?? this.timeString,
      period: period ?? this.period,
      recurrence: recurrence ?? this.recurrence,
      customDaysDisplay: customDaysDisplay ?? this.customDaysDisplay,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      weekdays: weekdays ?? this.weekdays,
      specificDate: specificDate ?? this.specificDate,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality
  // ---------------------------------------------------------------------------

  @override
  List<Object?> get props => [
    id,
    title,
    timeString,
    period,
    recurrence,
    customDaysDisplay,
    isActive,
    updatedAt,
    weekdays,
    specificDate,
  ];

  // ---------------------------------------------------------------------------
  // Static Display Logic
  // ---------------------------------------------------------------------------

  /// Builds the display string for custom recurrence patterns
  static String buildDaysDisplay({
    required RecurrenceType recurrence,
    required List<int> weekdays,
    DateTime? specificDate,
  }) {
    if (recurrence == RecurrenceType.weekly) {
      if (weekdays.isEmpty) return 'Weekly';

      const weekdayOptions = [
        {'label': 'Mon', 'day': 1},
        {'label': 'Tue', 'day': 2},
        {'label': 'Wed', 'day': 3},
        {'label': 'Thu', 'day': 4},
        {'label': 'Fri', 'day': 5},
        {'label': 'Sat', 'day': 6},
        {'label': 'Sun', 'day': 7},
      ];

      final selectedLabels = weekdays
          .map((day) => weekdayOptions.firstWhere((e) => e['day'] == day)['label'] as String)
          .toList();

      return selectedLabels.join(', ');
    }

    if (recurrence == RecurrenceType.oneTime) {
      return specificDate == null
          ? 'One time'
          : DateFormat.yMMMd().format(specificDate);
    }

    if (recurrence == RecurrenceType.monthly) {
      if (specificDate == null) return 'Monthly';
      final day = specificDate.day;
      String suffix = 'th';
      if (day < 11 || day > 13) {
        switch (day % 10) {
          case 1:
            suffix = 'st';
            break;
          case 2:
            suffix = 'nd';
            break;
          case 3:
            suffix = 'rd';
            break;
        }
      }
      return 'Monthly on the $day$suffix';
    }

    return 'Every Day';
  }

  // ---------------------------------------------------------------------------
  // Private field coercion helpers
  //
  // These replace the previous `(data['field'] as String?) ?? fallback`
  // pattern used in the original fromDoc.
  //
  // The problem with `as String?`:
  //   - Null passes through fine — but only null.
  //   - Any non-null, non-String value (int, double, bool stored in Firestore
  //     due to a schema mismatch or old app version) throws TypeError at
  //     runtime. The `?? fallback` does NOT catch cast errors, only null.
  //   - An empty string '' is not null, so `?? fallback` never fires for it.
  //
  // These helpers are intentionally static — factory constructors cannot
  // reference instance methods.
  // ---------------------------------------------------------------------------

  /// Safely extracts a non-empty String field.
  /// Returns [fallback] for null, wrong type, or empty string.
  static String _safeString(dynamic raw, String fallback) {
    if (raw == null) return fallback;
    if (raw is! String) return fallback;
    if (raw.isEmpty) return fallback;
    return raw;
  }

  /// Safely extracts and validates a 12-hour 'H:mm' / 'HH:mm' timeString.
  ///
  /// This is the model-boundary fix that prevents:
  ///   RangeError (length): Invalid value: Only valid value is 0: 1
  ///
  /// A corrupt timeString (missing colon, wrong type, empty, 'null' literal)
  /// is caught here and replaced with '00:00' before it ever reaches
  /// split(':') in FakeCallService or LoopBloc.
  ///
  /// [docId] is used purely for log context.
  static String _safeTimeString(dynamic raw, String docId) {
    if (raw == null) return '00:00'; // Missing field — silent fallback

    if (raw is! String) {
      AppLogger.warning(
        '[TaskLoopItem] Non-String timeString ($raw : ${raw.runtimeType}) '
            'for task $docId — defaulting to 00:00',
      );
      return '00:00';
    }

    if (raw.isEmpty || raw == 'null') {
      AppLogger.warning(
        '[TaskLoopItem] Empty/null-literal timeString '
            'for task $docId — defaulting to 00:00',
      );
      return '00:00';
    }

    final parts = raw.split(':');
    if (parts.length < 2) {
      // Exact guard for the reported RangeError: no colon → 1-element list →
      // index [1] invalid.
      AppLogger.warning(
        '[TaskLoopItem] Malformed timeString="$raw" (no colon) '
            'for task $docId — defaulting to 00:00',
      );
      return '00:00';
    }

    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());

    if (hour == null || minute == null) {
      AppLogger.warning(
        '[TaskLoopItem] Non-numeric timeString="$raw" '
            'for task $docId — defaulting to 00:00',
      );
      return '00:00';
    }

    if (hour < 0 || hour > 12 || minute < 0 || minute > 59) {
      AppLogger.warning(
        '[TaskLoopItem] Out-of-range timeString="$raw" '
            '(hour=$hour, minute=$minute) for task $docId — defaulting to 00:00',
      );
      return '00:00';
    }

    return raw;
  }

  /// Safely extracts and normalises a period field ('AM' / 'PM').
  /// Accepts any casing. Returns 'AM' for any unrecognised value.
  static String _safePeriod(dynamic raw, String docId) {
    if (raw == null) return 'AM';

    if (raw is! String) {
      AppLogger.warning(
        '[TaskLoopItem] Non-String period ($raw : ${raw.runtimeType}) '
            'for task $docId — defaulting to AM',
      );
      return 'AM';
    }

    final normalised = raw.trim().toUpperCase();
    if (normalised == 'AM' || normalised == 'PM') return normalised;

    AppLogger.warning(
      '[TaskLoopItem] Unrecognised period="$raw" '
          'for task $docId — defaulting to AM',
    );
    return 'AM';
  }

  /// Safely extracts a bool field.
  /// Returns [fallback] for any non-bool value (0/1 as int, 'true' as String).
  static bool _safeBool(dynamic raw, {required bool fallback}) {
    if (raw is bool) return raw;
    return fallback;
  }
}