import 'package:intl/intl.dart';

// ============================================================
// DATE TIME EXTENSIONS - For HomeScreen + TaskModel
// ============================================================

extension DateTimeTaskExtensions on DateTime {
  /// ✅ Returns "Today", "Tomorrow", or "DD/MM"
  String get taskDueDisplay {
    final now = DateTime.now();
    if (year == now.year && month == now.month && day == now.day) {
      return 'Today ${_formatTime(this)}';
    }
    if (year == now.year && month == now.month && day == now.day + 1) {
      return 'Tomorrow ${_formatTime(this)}';
    }
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}';
  }

  /// ✅ Time in "HH:MM" format
  String get timeDisplay => _formatTime(this);

  /// ✅ Short date "DD/MM"
  String get shortDisplay => '$day/$month';

  /// ✅ Is task urgent? (within 2 hours)
  bool get isUrgent {
    final now = DateTime.now();
    final diff = difference(now);
    return diff.inHours <= 2 && isAfter(now);
  }

  /// ✅ Is upcoming (future date)
  bool get isUpcoming => isAfter(DateTime.now());

  /// ✅ Format time as "14:30"
  String _formatTime(DateTime date) {
    final formatter = DateFormat('HH:mm');
    return formatter.format(date);
  }
}

/// ✅ DateTimeHelper - Static utilities (for main.dart header)
class DateTimeHelper {
  /// ✅ Readable date for header: "Today" or "19 Jan"
  static String formatReadableDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month) {
      return 'Today';
    }
    final formatter = DateFormat('dd MMM');
    return formatter.format(date);
  }

  /// ✅ Current time in local timezone
  static DateTime nowTz() => DateTime.now();

  /// ✅ Is valid task date (not null, not too far future)
  static bool isValidTaskDate(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final diff = date.difference(now);
    return diff.inDays <= 365; // Max 1 year ahead
  }

  /// ✅ Is task urgent (within 2 hours)
  static bool isUrgent(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    return diff.inHours <= 2 && date.isAfter(now);
  }
}
