// Validators for form validation across the app
// Provides reusable validation logic for auth, tasks, and settings

class Validators {
  // Private constructor to prevent instantiation
  Validators._();

  // ---------------------------------------------------------------------------
  // 📧 EMAIL VALIDATION
  // ---------------------------------------------------------------------------

  /// Validates email format
  /// Returns null if valid, error message if invalid
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    // Email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 🔐 PASSWORD VALIDATION
  // ---------------------------------------------------------------------------

  /// Validates password strength
  /// Minimum 8 characters with at least one letter and one number
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Check for at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Password must contain at least one letter';
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Validates password confirmation
  static String? confirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != originalPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Strong password validation (optional - for enhanced security)
  /// Requires uppercase, lowercase, number, and special character
  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 👤 NAME VALIDATION
  // ---------------------------------------------------------------------------

  /// Validates user's full name
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value.trim())) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }

    return null;
  }

  /// Validates first or last name
  static String? firstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'First name is required';
    }

    if (value.trim().length < 2) {
      return 'First name must be at least 2 characters';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // ✅ TASK VALIDATION
  // ---------------------------------------------------------------------------

  /// Validates task title/name
  static String? taskTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Task title is required';
    }

    if (value.trim().length < 3) {
      return 'Task title must be at least 3 characters';
    }

    if (value.trim().length > 100) {
      return 'Task title must not exceed 100 characters';
    }

    return null;
  }

  /// Validates task description (optional field)
  static String? taskDescription(String? value) {
    // Description is optional, so null/empty is valid
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    if (value.trim().length > 500) {
      return 'Description must not exceed 500 characters';
    }

    return null;
  }

  /// Validates task time is in the future
  static String? futureDateTime(DateTime? value) {
    if (value == null) {
      return 'Date and time is required';
    }

    final now = DateTime.now();
    if (value.isBefore(now)) {
      return 'Please select a future date and time';
    }

    return null;
  }

  /// Validates scheduled time is not too far in the future (optional limit)
  static String? scheduledTime(DateTime? value, {int maxDaysInFuture = 365}) {
    if (value == null) {
      return 'Scheduled time is required';
    }

    final now = DateTime.now();
    if (value.isBefore(now)) {
      return 'Scheduled time must be in the future';
    }

    final maxDate = now.add(Duration(days: maxDaysInFuture));
    if (value.isAfter(maxDate)) {
      return 'Scheduled time cannot be more than $maxDaysInFuture days in the future';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 📞 PHONE NUMBER VALIDATION
  // ---------------------------------------------------------------------------

  /// Validates phone number format (basic validation)
  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    // Remove common formatting characters
    final cleaned = value.replaceAll(RegExp(r'[\s\-()+]'), '');

    // Check if it contains only digits after cleaning
    if (!RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
      return 'Phone number can only contain digits';
    }

    // Check length (typically 10-15 digits)
    if (cleaned.length < 10 || cleaned.length > 15) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 🔢 GENERAL VALIDATION
  // ---------------------------------------------------------------------------

  /// Validates required field (generic)
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates minimum length
  static String? minLength(String? value, int minLength,
      {String fieldName = 'Field'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    return null;
  }

  /// Validates maximum length
  static String? maxLength(String? value, int maxLength,
      {String fieldName = 'Field'}) {
    if (value == null) {
      return null;
    }

    if (value.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }

    return null;
  }

  /// Validates numeric input
  static String? numeric(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    if (double.tryParse(value) == null) {
      return '$fieldName must be a valid number';
    }

    return null;
  }

  /// Validates integer input
  static String? integer(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    if (int.tryParse(value) == null) {
      return '$fieldName must be a valid whole number';
    }

    return null;
  }

  /// Validates value is within range
  static String? range(String? value, int min, int max,
      {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final number = int.tryParse(value);
    if (number == null) {
      return '$fieldName must be a valid number';
    }

    if (number < min || number > max) {
      return '$fieldName must be between $min and $max';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 🔗 URL VALIDATION
  // ---------------------------------------------------------------------------

  /// Validates URL format
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL is required';
    }

    final urlRegex = RegExp(
      r'^https?://(?:www\.)?[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b[-a-zA-Z0-9()@:%_+.~#?&/=]*$',
    );

    if (!urlRegex.hasMatch(value.trim())) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 🔍 CUSTOM VALIDATORS
  // ---------------------------------------------------------------------------

  /// Combines multiple validators
  static String? Function(String?) combine(
      List<String? Function(String?)> validators) {
    return (String? value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) {
          return result;
        }
      }
      return null;
    };
  }
}