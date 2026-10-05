/// Standard input validation utilities
class Validators {
  Validators._();

  static String? requiredField(String? value, [String message = 'This field is required']) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? validNumber(String? value, [String message = 'Enter a valid number']) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    final clean = value.replaceAll(',', '').trim();
    final num = double.tryParse(clean);
    if (num == null) {
      return message;
    }
    if (num < 0) {
      return 'Value cannot be negative';
    }
    return null;
  }

  static String? validQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Quantity required';
    }
    final num = double.tryParse(value.trim());
    if (num == null || num <= 0) {
      return 'Must be greater than 0';
    }
    return null;
  }

  static String? validPin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PIN is required';
    }
    if (value.trim().length < 4) {
      return 'PIN must be at least 4 digits';
    }
    return null;
  }

  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }
}
