import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class TaskModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime? scheduledTime;
  final bool isCompleted;
  final bool isReminderEnabled;
  final bool isUrgent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Sync metadata (local-only, never sent to Firestore) ──────────────────
  final bool isSynced;
  final bool isDeletedLocally;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    this.scheduledTime,
    this.isCompleted = false,
    this.isReminderEnabled = true,
    this.isUrgent = false,
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.isDeletedLocally = false,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? scheduledTime,
    bool? isCompleted,
    bool? isReminderEnabled,
    bool? isUrgent,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearScheduledTime = false,
    bool? isSynced,
    bool? isDeletedLocally,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime:
      clearScheduledTime ? null : (scheduledTime ?? this.scheduledTime),
      isCompleted: isCompleted ?? this.isCompleted,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      isUrgent: isUrgent ?? this.isUrgent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeletedLocally: isDeletedLocally ?? this.isDeletedLocally,
    );
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  /// Parses a Firestore document into a TaskModel.
  /// isSynced is set to true here because data coming from Firestore is, by
  /// definition, already in sync. isDeletedLocally defaults to false.
  factory TaskModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return TaskModel(
      id: docId,
      title: data['title'] as String? ?? 'Untitled Task',
      description: data['description'] as String? ?? '',
      scheduledTime: _parseDateTime(data['scheduledTime']),
      isCompleted: data['isCompleted'] as bool? ?? false,
      isReminderEnabled: data['isReminderEnabled'] as bool? ?? true,
      isUrgent: data['isUrgent'] as bool? ?? false,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      isSynced: true,         // freshly fetched → already synced
      isDeletedLocally: false,
    );
  }

  /// Sends to Firestore. Sync metadata is intentionally excluded — it is
  /// local state only and must never pollute the remote document.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'scheduledTime':
      scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'isCompleted': isCompleted,
      'isReminderEnabled': isReminderEnabled,
      'isUrgent': isUrgent,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // isSynced and isDeletedLocally are deliberately omitted
    };
  }

  // ── Cache / SharedPreferences (via CacheManager) ──────────────────────────

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Task',
      description: json['description'] as String? ?? '',
      scheduledTime: _parseDateTime(json['scheduledTime']),
      isCompleted: json['isCompleted'] as bool? ?? false,
      isReminderEnabled: json['isReminderEnabled'] as bool? ?? true,
      isUrgent: json['isUrgent'] as bool? ?? false,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      isSynced: json['isSynced'] as bool? ?? false,
      isDeletedLocally: json['isDeletedLocally'] as bool? ?? false,
    );
  }

  /// Persisted to SharedPreferences via CacheManager.
  /// Sync metadata IS included here — it is the source of truth for local
  /// pending-sync and soft-delete state.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'isCompleted': isCompleted,
      'isReminderEnabled': isReminderEnabled,
      'isUrgent': isUrgent,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isSynced': isSynced,
      'isDeletedLocally': isDeletedLocally,
    };
  }

  // ── WorkManager ───────────────────────────────────────────────────────────

  Map<String, dynamic> toJsonForWorkManager() {
    return {
      'taskId': id,
      'title': title,
      'description': description,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'isCompleted': isCompleted,
      'isReminderEnabled': isReminderEnabled,
      'isUrgent': isUrgent,
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Single robust DateTime parser — handles Timestamp, DateTime, ISO String,
  /// and epoch int without any switch-statement warnings.
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  // ── Display ───────────────────────────────────────────────────────────────

  String displayScheduledTimeFormatted({bool use24HourFormat = true}) {
    if (scheduledTime == null) return 'No due date';

    final now = DateTime.now();
    final taskDate = scheduledTime!;
    final timeFormat = use24HourFormat ? 'HH:mm' : 'h:mm a';

    if (_isSameDay(taskDate, now)) {
      return 'Today ${DateFormat(timeFormat).format(taskDate)}';
    }
    if (_isSameDay(taskDate, now.add(const Duration(days: 1)))) {
      return 'Tomorrow ${DateFormat(timeFormat).format(taskDate)}';
    }
    if (taskDate.isBefore(now)) {
      return 'Overdue • ${DateFormat('MMM d').format(taskDate)}';
    }
    if (taskDate.difference(now).inDays <= 7) {
      return '${DateFormat('EEE, MMM d').format(taskDate)} ${DateFormat(timeFormat).format(taskDate)}';
    }
    return '${DateFormat('MMM d, y').format(taskDate)} ${DateFormat(timeFormat).format(taskDate)}';
  }

  @Deprecated('Use displayScheduledTimeFormatted instead')
  String get displayScheduledTime => displayScheduledTimeFormatted();

  String get timeUntilString {
    final duration = timeUntilTask;
    if (duration == null) return '';
    if (duration.isNegative) {
      final abs = duration.abs();
      return abs.inDays > 0 ? '${abs.inDays}d overdue' : 'Overdue';
    }
    return duration.inDays > 0
        ? 'in ${duration.inDays}d'
        : duration.inHours > 0
        ? 'in ${duration.inHours}h'
        : 'Soon';
  }

  bool get isOverdue =>
      scheduledTime != null &&
          scheduledTime!.isBefore(DateTime.now()) &&
          !isCompleted;

  bool get isDueToday =>
      scheduledTime != null && _isSameDay(scheduledTime!, DateTime.now());

  Duration? get timeUntilTask => scheduledTime?.difference(DateTime.now());

  bool get isValid => id.isNotEmpty && title.trim().isNotEmpty;

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  // ── Equatable ─────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    scheduledTime,
    isCompleted,
    isReminderEnabled,
    isUrgent,
    createdAt,
    updatedAt,
    isSynced,
    isDeletedLocally,
  ];

  @override
  String toString() =>
      'Task(id: $id, title: "$title", due: $displayScheduledTime, '
          'urgent: $isUrgent, done: $isCompleted, '
          'synced: $isSynced, deletedLocally: $isDeletedLocally)';
}