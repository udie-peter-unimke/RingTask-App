// lib/data/models/loop_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:ringtask/utils/logger.dart';

enum RecurrenceType { daily, weekly, monthly }

RecurrenceType recurrenceFromString(String s) {
  switch (s) {
    case 'weekly':
      return RecurrenceType.weekly;
    case 'monthly':
      return RecurrenceType.monthly;
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

  const TaskLoopItem({
    required this.id,
    required this.title,
    required this.timeString,
    required this.period,
    required this.recurrence,
    required this.customDaysDisplay,
    required this.isActive,
    this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Firestore deserialization
  // ---------------------------------------------------------------------------

  factory TaskLoopItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return TaskLoopItem(
      id: doc.id,
      title: _safeString(data['title'], 'Untitled'),
      timeString: _safeTimeString(data['timeString'], doc.id),
      period: _safePeriod(data['period'], doc.id),
      recurrence: recurrenceFromString(_safeString(data['recurrence'], 'daily')),
      customDaysDisplay: _safeString(data['customDaysDisplay'], 'Every Day'),
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
    return TaskLoopItem(
      id: json['id'] is String ? json['id'] as String : '',
      title: _safeString(json['title'], 'Untitled'),
      timeString: _safeTimeString(json['timeString'], contextId),
      period: _safePeriod(json['period'], contextId),
      recurrence: recurrenceFromString(_safeString(json['recurrence'], 'daily')),
      customDaysDisplay: _safeString(json['customDaysDisplay'], 'Every Day'),
      isActive: _safeBool(json['isActive'], fallback: true),
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
  ];

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