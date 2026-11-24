/// Form field validators. Each returns an error message or null when valid.
abstract final class Validators {
  static String? required(String? v, [String label = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  static String? email(String? v, {bool requiredField = true}) {
    if (v == null || v.trim().isEmpty) return requiredField ? 'Email is required' : null;
    final ok = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? phone(String? v, {bool requiredField = false}) {
    if (v == null || v.trim().isEmpty) return requiredField ? 'Phone number is required' : null;
    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 7 && digits.length <= 15 ? null : 'Enter a valid phone number';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    return v.length < 6 ? 'Use at least 6 characters' : null;
  }

  static String? amount(String? v, {String label = 'Amount', bool allowZero = false}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = double.tryParse(v.replaceAll(',', '').trim());
    if (n == null) return 'Enter a valid number';
    if (n < 0 || (!allowZero && n == 0)) return '$label must be greater than 0';
    return null;
  }

  static String? percent(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.trim());
    if (n == null || n < 0 || n > 100) return '0 – 100';
    return null;
  }
}

double parseAmount(String? v) => double.tryParse((v ?? '').replaceAll(',', '').trim()) ?? 0;
