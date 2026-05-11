// lib/utils/date_time_helper.dart - ✅ 2026 READY
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// RingTask DateTime Utility - All task scheduling & display formatting
class DateTimeHelper {
  DateTimeHelper._(); // Private constructor - static utility class

  // === FORMATTING (Task UI Display) ===

  /// "Jan 19, 2026" - List view dates
  static String formatShortDate(DateTime date) =>
      DateFormat('MMM d, yyyy', 'en_US').format(date);

  /// "Sunday, Jan 19 • 3:21 PM" - Task detail header
  static String formatReadableDateTime(DateTime date) =>
      '${DateFormat('EEE, MMM d', 'en_US').format(date)} • ${formatTime12Hour(date)}';

  /// "3:21 PM" - Time pickers & notifications
  static String formatTime12Hour(DateTime date) =>
      DateFormat('h:mm a', 'en_US').format(date);

  /// "15:21" - 24hr format
  static String formatTime24Hour(DateTime date) =>
      DateFormat('HH:mm', 'en_US').format(date);

  /// "Due: Today 3:21 PM" - Compact task display
  static String formatTaskDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final diff = dueDate.difference(now).inDays;

    if (diff == 0) return 'Today ${formatTime12Hour(dueDate)}';
    if (diff == 1) return 'Tomorrow ${formatTime12Hour(dueDate)}';
    if (diff < 7) return 'in $diff days';

    return 'Due ${formatShortDate(dueDate)}';
  }

  // === PARSING ===

  /// Safe ISO parsing for Firestore timestamps
  static DateTime? safeParse(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  // === VALIDATION ===

  /// Valid task date (not null, not invalid)
  static bool isValidTaskDate(DateTime? date) =>
      date != null && date.millisecondsSinceEpoch > 0;

  /// Task is upcoming (within 24h for reminders)
  static bool isUpcoming(DateTime date) {
    final now = DateTime.now();
    return date.isAfter(now) && date.difference(now).inHours <= 24;
  }

  // === CALCULATIONS ===

  /// Start of day: 2026-01-19 00:00:00.000
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// End of day: 2026-01-19 23:59:59.999
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  /// Next reminder time (add 5min buffer)
  static DateTime nextReminderTime(DateTime dueDate) =>
      startOfDay(dueDate).add(const Duration(hours: 9)); // 9AM next day

  /// Days until due date
  static int daysUntil(DateTime dueDate) =>
      dueDate.difference(DateTime.now()).inDays;

  // === TASK SCHEDULING ===

  /// Format for WorkManager notification
  static String formatNotificationDate(DateTime date) =>
      DateFormat('MMM d, h:mm a', 'en_US').format(date);

  /// Firestore timestamp string
  static String toFirestoreTimestamp(DateTime date) =>
      date.toIso8601String();

  // === TIMEZONE (for AlarmScheduler) ===

  static tz.TZDateTime toTzLocal(DateTime date) =>
      tz.TZDateTime.from(date, tz.local);

  static tz.TZDateTime nowTz() => tz.TZDateTime.now(tz.local);
}

/// === EXTENSIONS - Clean task model usage ===
extension DateTimeTaskExt on DateTime {
  /// "Today 3:21 PM", "Tomorrow 9:00 AM", "Jan 19"
  String get taskDueDisplay => DateTimeHelper.formatTaskDueDate(this);

  /// "3:21 PM"
  String get timeDisplay => DateTimeHelper.formatTime12Hour(this);

  /// "Jan 19, 2026"
  String get shortDisplay => DateTimeHelper.formatShortDate(this);

  /// true if task due within 24h
  bool get isUrgent => DateTimeHelper.isUpcoming(this);

  /// Start of this day
  DateTime get startOfDay => DateTimeHelper.startOfDay(this);

  /// End of this day
  DateTime get endOfDay => DateTimeHelper.endOfDay(this);
}
