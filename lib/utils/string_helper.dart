// String helper utilities for the RingTask app
// Provides string manipulation, formatting, and transformation functions

import 'package:intl/intl.dart';

class StringHelper {
  // Private constructor to prevent instantiation
  StringHelper._();

  // ---------------------------------------------------------------------------
  // 🔤 CASE TRANSFORMATIONS
  // ---------------------------------------------------------------------------

  /// Capitalizes first letter of a string
  /// Example: "hello world" → "Hello world"
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Capitalizes first letter of each word (Title Case)
  /// Example: "hello world" → "Hello World"
  static String toTitleCase(String text) {
    if (text.isEmpty) return text;

    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Converts to sentence case
  /// Example: "HELLO WORLD" → "Hello world"
  static String toSentenceCase(String text) {
    if (text.isEmpty) return text;
    final lower = text.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  /// Converts to camelCase
  /// Example: "hello world app" → "helloWorldApp"
  static String toCamelCase(String text) {
    if (text.isEmpty) return text;

    final words = text.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return text;

    final first = words.first.toLowerCase();
    final rest = words.skip(1).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });

    return first + rest.join('');
  }

  /// Converts to snake_case
  /// Example: "Hello World App" → "hello_world_app"
  static String toSnakeCase(String text) {
    if (text.isEmpty) return text;

    return text
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // ✂️ TRUNCATION & ELLIPSIS
  // ---------------------------------------------------------------------------

  /// Truncates string to specified length with ellipsis
  /// Example: truncate("Hello World", 8) → "Hello..."
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - ellipsis.length) + ellipsis;
  }

  /// Truncates string at word boundary
  /// Example: truncateWords("Hello World App", 12) → "Hello World..."
  static String truncateWords(String text, int maxLength,
      {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;

    int endIndex = maxLength - ellipsis.length;
    final lastSpace = text.lastIndexOf(' ', endIndex);

    if (lastSpace > 0) {
      return text.substring(0, lastSpace) + ellipsis;
    }

    return text.substring(0, endIndex) + ellipsis;
  }

  // ---------------------------------------------------------------------------
  // 🧹 CLEANING & SANITIZATION
  // ---------------------------------------------------------------------------

  /// Removes extra whitespace (multiple spaces become single space)
  static String removeExtraSpaces(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Removes all whitespace
  static String removeAllSpaces(String text) {
    return text.replaceAll(RegExp(r'\s+'), '');
  }

  /// Removes special characters (keeps alphanumeric and spaces)
  static String removeSpecialCharacters(String text) {
    return text.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
  }

  /// Removes emojis from text
  static String removeEmojis(String text) {
    return text.replaceAll(
      RegExp(
        r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
        unicode: true,
      ),
      '',
    );
  }

  /// Sanitizes input for safe display (removes dangerous characters)
  static String sanitize(String text) {
    return text
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  // ---------------------------------------------------------------------------
  // 🔍 VALIDATION HELPERS
  // ---------------------------------------------------------------------------

  /// Checks if string is null or empty
  static bool isNullOrEmpty(String? text) {
    return text == null || text.isEmpty;
  }

  /// Checks if string is null, empty, or only whitespace
  static bool isNullOrWhitespace(String? text) {
    return text == null || text.trim().isEmpty;
  }

  /// Checks if string contains only letters
  static bool isAlpha(String text) {
    return RegExp(r'^[a-zA-Z]+$').hasMatch(text);
  }

  /// Checks if string contains only numbers
  static bool isNumeric(String text) {
    return RegExp(r'^[0-9]+$').hasMatch(text);
  }

  /// Checks if string is alphanumeric
  static bool isAlphanumeric(String text) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
  }

  /// Checks if string is a valid email
  static bool isEmail(String text) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(text);
  }

  // ---------------------------------------------------------------------------
  // 🎭 MASKING & PRIVACY
  // ---------------------------------------------------------------------------

  /// Masks email address
  /// Example: "john.doe@example.com" → "j***e@example.com"
  static String maskEmail(String email) {
    if (!isEmail(email)) return email;

    final parts = email.split('@');
    final username = parts[0];

    if (username.length <= 2) {
      return '${username[0]}***@${parts[1]}';
    }

    final masked =
        username[0] + ('*' * (username.length - 2)) + username[username.length - 1];
    return '$masked@${parts[1]}';
  }

  /// Masks phone number
  /// Example: "1234567890" → "***-***-7890"
  static String maskPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.length < 4) return phone;

    final lastFour = cleaned.substring(cleaned.length - 4);
    return '***-***-$lastFour';
  }

  /// Masks credit card number
  /// Example: "1234567890123456" → "****-****-****-3456"
  static String maskCreditCard(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.length < 4) return cardNumber;

    final lastFour = cleaned.substring(cleaned.length - 4);
    return '****-****-****-$lastFour';
  }

  // ---------------------------------------------------------------------------
  // 📏 COUNTING & ANALYSIS
  // ---------------------------------------------------------------------------

  /// Counts words in a string
  static int wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Counts characters excluding whitespace
  static int characterCount(String text, {bool includeSpaces = true}) {
    if (includeSpaces) {
      return text.length;
    }
    return text.replaceAll(RegExp(r'\s+'), '').length;
  }

  /// Counts occurrences of a substring
  static int countOccurrences(String text, String substring) {
    if (substring.isEmpty) return 0;
    return substring.allMatches(text).length;
  }

  // ---------------------------------------------------------------------------
  // 🔄 PLURALIZATION
  // ---------------------------------------------------------------------------

  /// Returns plural form based on count
  /// Example: pluralize(1, 'task') → "1 task", pluralize(5, 'task') → "5 tasks"
  static String pluralize(int count, String singular, {String? plural}) {
    plural ??= '${singular}s';
    return '$count ${count == 1 ? singular : plural}';
  }

  /// Returns "is" or "are" based on count
  static String isOrAre(int count) {
    return count == 1 ? 'is' : 'are';
  }

  /// Returns "has" or "have" based on count
  static String hasOrHave(int count) {
    return count == 1 ? 'has' : 'have';
  }

  // ---------------------------------------------------------------------------
  // 📅 FORMATTING
  // ---------------------------------------------------------------------------

  /// Formats number with thousand separators
  /// Example: 1234567 → "1,234,567"
  static String formatNumber(num number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  /// Formats currency
  /// Example: 1234.56 → "$1,234.56"
  static String formatCurrency(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  /// Formats percentage
  /// Example: 0.856 → "85.6%"
  static String formatPercentage(double value, {int decimals = 1}) {
    final formatter = NumberFormat.percentPattern();
    formatter.minimumFractionDigits = decimals;
    formatter.maximumFractionDigits = decimals;
    return formatter.format(value);
  }

  /// Formats file size
  /// Example: 1536 → "1.5 KB", 1048576 → "1.0 MB"
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  // ---------------------------------------------------------------------------
  // 🎨 INITIALS & ABBREVIATIONS
  // ---------------------------------------------------------------------------

  /// Gets initials from name
  /// Example: "John Doe" → "JD", "Mary Jane Watson" → "MJW"
  static String getInitials(String name, {int maxInitials = 2}) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(maxInitials)
        .map((word) => word[0].toUpperCase());

    return initials.join('');
  }

  /// Creates abbreviation from text
  /// Example: "Very Important Person" → "VIP"
  static String abbreviate(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    return words.map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase();
    }).join('');
  }

  // ---------------------------------------------------------------------------
  // 🔗 URL & LINK HELPERS
  // ---------------------------------------------------------------------------

  /// Extracts domain from URL
  /// Example: "https://www.example.com/path" → "example.com"
  static String? extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host;
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      return host;
    } catch (e) {
      return null;
    }
  }

  /// Checks if string contains URL
  static bool containsUrl(String text) {
    return RegExp(
      r'https?://(?:www\.)?[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b[-a-zA-Z0-9()@:%_+.~#?&/=]*',
    ).hasMatch(text);
  }

  // ---------------------------------------------------------------------------
  // 🎯 COMPARISON & SIMILARITY
  // ---------------------------------------------------------------------------

  /// Calculates Levenshtein distance between two strings
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final List<List<int>> matrix = List.generate(
      s1.length + 1,
          (i) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Calculates similarity percentage between two strings
  /// Returns value between 0.0 and 1.0
  static double similarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLength = s1.length > s2.length ? s1.length : s2.length;
    final distance = levenshteinDistance(s1.toLowerCase(), s2.toLowerCase());

    return 1.0 - (distance / maxLength);
  }

  // ---------------------------------------------------------------------------
  // 🔐 HASH & ENCODING
  // ---------------------------------------------------------------------------

  /// Generates simple hash code for string
  static int generateHashCode(String text) {
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = ((hash << 5) - hash) + text.codeUnitAt(i);
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.abs();
  }

  // ---------------------------------------------------------------------------
  // 🎲 RANDOM GENERATION
  // ---------------------------------------------------------------------------

  /// Generates random string of specified length
  static String randomString(int length,
      {bool includeNumbers = true, bool includeSpecial = false}) {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const special = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    String chars = letters;
    if (includeNumbers) chars += numbers;
    if (includeSpecial) chars += special;

    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) {
      final i = (random + index) % chars.length;
      return chars[i];
    }).join();
  }
}