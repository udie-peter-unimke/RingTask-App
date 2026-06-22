class ParsedTask {
  final String title;
  final DateTime? dateTime;

  ParsedTask({required this.title, this.dateTime});

  @override
  String toString() => 'ParsedTask(title: $title, dateTime: $dateTime)';
}

class TaskParser {
  /// Parses voice input to extract a task title and an optional date/time.
  /// Example: "Buy milk tomorrow at 5pm" -> title: "Buy milk", dateTime: [Tomorrow 5:00 PM]
  static ParsedTask parseVoiceInput(String input) {
    if (input.isEmpty) return ParsedTask(title: '');

    String workingText = input.toLowerCase().trim();
    DateTime now = DateTime.now();
    DateTime? parsedDate;

    // 1. Check for relative day keywords
    if (workingText.contains('tomorrow')) {
      parsedDate = DateTime(now.year, now.month, now.day + 1);
      workingText = workingText.replaceAll('tomorrow', '').trim();
    } else if (workingText.contains('today')) {
      parsedDate = DateTime(now.year, now.month, now.day);
      workingText = workingText.replaceAll('today', '').trim();
    } else {
      // Check for specific days of the week
      final daysOfWeek = {
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
        'friday': DateTime.friday,
        'saturday': DateTime.saturday,
        'sunday': DateTime.sunday,
      };

      for (var entry in daysOfWeek.entries) {
        if (workingText.contains(entry.key)) {
          int daysUntil = entry.value - now.weekday;
          if (daysUntil <= 0) daysUntil += 7;
          parsedDate = DateTime(now.year, now.month, now.day + daysUntil);
          workingText = workingText.replaceAll(entry.key, '').trim();
          break;
        }
      }
    }

    // Default to today if no day was found but "at" or "in" is present
    parsedDate ??= DateTime(now.year, now.month, now.day);

    // 2. Check for "in X hours/minutes" relative time
    final relativeTimeRegex = RegExp(r'in\s+(\d+)\s+(hour|minute)s?');
    final relativeMatch = relativeTimeRegex.firstMatch(workingText);
    if (relativeMatch != null) {
      final value = int.parse(relativeMatch.group(1)!);
      final unit = relativeMatch.group(2)!;
      
      if (unit.startsWith('hour')) {
        parsedDate = now.add(Duration(hours: value));
      } else {
        parsedDate = now.add(Duration(minutes: value));
      }
      
      workingText = workingText.replaceAll(relativeMatch.group(0)!, '').trim();
      return _finalize(workingText, parsedDate);
    }

    // 3. Check for specific time formats (e.g., "at 5pm", "at 17:30", "at 5")
    final timeRegex = RegExp(r'(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?');
    final timeMatch = timeRegex.firstMatch(workingText);
    
    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      int minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      String? amPm = timeMatch.group(3);

      if (amPm == 'pm' && hour < 12) hour += 12;
      if (amPm == 'am' && hour == 12) hour = 0;

      parsedDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        hour,
        minute,
      );

      // If the time is in the past and no specific day was mentioned, assume tomorrow
      if (parsedDate.isBefore(now) && !input.toLowerCase().contains('today')) {
         // Only advance if it was a generic "at X" without a day prefix that we already handled
         // But actually, if they said "at 10am" and it's 11am, they probably mean tomorrow.
         parsedDate = parsedDate.add(const Duration(days: 1));
      }

      workingText = workingText.replaceAll(timeMatch.group(0)!, '').trim();
    } else {
      // If no time was matched, default to a sensible time (e.g., 1 hour from now or 9 AM tomorrow)
      if (input.toLowerCase().contains('tomorrow') || input.toLowerCase().contains('today')) {
        // Keep the date but maybe set a default time if none provided?
        // Let's stick to the date found and set it to 1 hour from now if today, or 9am if tomorrow.
        if (parsedDate.day == now.day) {
           parsedDate = now.add(const Duration(hours: 1));
        } else {
           parsedDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 9, 0);
        }
      } else {
        // No date or time found at all
        parsedDate = null;
      }
    }

    return _finalize(workingText, parsedDate);
  }

  static ParsedTask _finalize(String title, DateTime? dateTime) {
    // Clean up title (remove trailing/leading prepositions often left behind)
    String cleanedTitle = title
        .replaceAll(RegExp(r'\s+(at|on|for|in)$'), '')
        .replaceAll(RegExp(r'^(at|on|for|in)\s+'), '')
        .trim();
    
    // Capitalize first letter
    if (cleanedTitle.isNotEmpty) {
      cleanedTitle = cleanedTitle[0].toUpperCase() + cleanedTitle.substring(1);
    }

    return ParsedTask(
      title: cleanedTitle,
      dateTime: dateTime,
    );
  }
}
