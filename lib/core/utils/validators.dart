class Validators {
  const Validators._();

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmed)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? positiveInt(String? value, {String label = 'Value'}) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) return '$label must be above 0';
    return null;
  }

  static String? nonNegativeInt(String? value, {String label = 'Value'}) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 0) return '$label must be 0 or above';
    return null;
  }

  static String? positiveMoney(String? value, {String label = 'Price'}) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) return '$label must be above 0';
    return null;
  }
}
