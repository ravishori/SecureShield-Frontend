/// Centralised form validators — use these across all screens.
/// Each method returns null if valid, or an error message string if invalid.
class Validators {
  Validators._();

  /// Non-null, non-empty field.
  static String? required(String? v, {String message = 'This field is required'}) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }

  /// First/last name — letters, spaces, hyphens, apostrophes only.
  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    if (!RegExp(r"^[a-zA-Z\u0900-\u097F\u0980-\u09FF\u0B80-\u0BFF\u0C00-\u0C7F\u0A00-\u0A7F\u0B00-\u0B7F '\-]+$")
            .hasMatch(v.trim())) {
      return 'Name should only contain letters and spaces';
    }
    return null;
  }

  /// Standard email format.
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional by default
    if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Required email.
  static String? emailRequired(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email address is required';
    return email(v);
  }

  /// Phone: digits only, 7-15 characters.
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final digits = v.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\d{7,15}$').hasMatch(digits)) {
      return 'Enter a valid phone number (digits only)';
    }
    return null;
  }

  /// Optional phone — only validates if not empty.
  static String? phoneOptional(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return phone(v);
  }

  /// India PIN code — exactly 6 digits.
  static String? pinCode(String? v) {
    if (v == null || v.trim().isEmpty) return 'PIN code is required';
    if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
      return 'Enter a valid 6-digit PIN code';
    }
    return null;
  }

  /// Generic text field with min/max length.
  static String? Function(String?) minLength(int min, {String? label}) {
    return (String? v) {
      if (v == null || v.trim().length < min) {
        return '${label ?? 'This field'} must be at least $min characters';
      }
      return null;
    };
  }
}
