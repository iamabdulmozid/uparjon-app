/// Shared form validation. Messages are user-facing and will move to l10n.
abstract final class Validators {
  /// Bangladeshi mobile numbers: 01XXXXXXXXX, optionally +88 prefixed.
  static final RegExp _bdPhone = RegExp(r'^(?:\+?88)?01[3-9]\d{8}$');

  static String? required(String? value, {String field = 'This field'}) =>
      (value == null || value.trim().isEmpty) ? '$field is required' : null;

  static String? name(String? value) {
    final empty = required(value, field: 'Full name');
    if (empty != null) return empty;
    return value!.trim().length < 3 ? 'Please enter your full name' : null;
  }

  static String? phone(String? value) {
    final empty = required(value, field: 'Phone number');
    if (empty != null) return empty;
    return _bdPhone.hasMatch(value!.replaceAll(RegExp(r'[\s-]'), ''))
        ? null
        : 'Enter a valid Bangladeshi number (01XXXXXXXXX)';
  }

  /// The backend requires an email at registration even though its OpenAPI
  /// schema marks the field optional.
  static String? email(String? value) {
    final empty = required(value, field: 'Email');
    if (empty != null) return empty;
    final trimmed = value!.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(trimmed)
        ? null
        : 'Enter a valid email address';
  }

  static String? password(String? value) {
    final empty = required(value, field: 'Password');
    if (empty != null) return empty;
    return value!.length < 6 ? 'Use at least 6 characters' : null;
  }

  static String? confirmPassword(String? value, String original) {
    final empty = required(value, field: 'Confirm password');
    if (empty != null) return empty;
    return value == original ? null : 'Passwords do not match';
  }

  /// Masks either a phone number or an email for display.
  static String maskContact(String value) {
    return value.contains('@') ? maskEmail(value) : maskPhone(value);
  }

  /// Masks an email for display: mehedi@test.com → me****@test.com
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final head = email.substring(0, at < 3 ? 1 : 2);
    return '$head${'*' * (at - head.length)}${email.substring(at)}';
  }

  /// Masks a phone number for display: 01712345624 → +88017******24
  static String maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return phone;
    final local = digits.startsWith('88') ? digits.substring(2) : digits;
    final head = local.substring(0, 3);
    final tail = local.substring(local.length - 2);
    return '+88$head${'*' * (local.length - 5)}$tail';
  }
}
