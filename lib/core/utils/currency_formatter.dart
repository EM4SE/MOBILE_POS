import 'package:intl/intl.dart';
import '../../app/constants/app_constants.dart';

/// Central currency and number formatting utility
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _quantityFormat = NumberFormat('#,##0.##', 'en_US');

  /// Format a double amount as standard currency without symbol (e.g., 1,250.00)
  static String formatAmount(double amount) {
    return _currencyFormat.format(amount);
  }

  /// Format amount with currency symbol (e.g., Rs. 1,250.00)
  static String formatWithSymbol(double amount, [String? symbol]) {
    final sym = symbol ?? AppConstants.defaultCurrencySymbol;
    return '$sym${_currencyFormat.format(amount)}';
  }

  /// Format quantity showing decimals only when necessary (e.g., 2 or 2.5)
  static String formatQuantity(double quantity) {
    return _quantityFormat.format(quantity);
  }

  /// Parse user text into double safely
  static double parseDouble(String text, [double defaultValue = 0.0]) {
    final clean = text.replaceAll(',', '').trim();
    return double.tryParse(clean) ?? defaultValue;
  }
}
