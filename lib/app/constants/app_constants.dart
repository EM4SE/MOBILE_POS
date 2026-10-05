/// Global application constants
class AppConstants {
  AppConstants._();

  static const String appName = 'ONIMTA POS';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Fast • Reliable • Local-First';

  // Currency & Locale
  static const String defaultCurrencySymbol = 'Rs. ';
  static const String defaultLocale = 'en_US';

  // Pagination defaults
  static const int defaultPageSize = 25;

  // POS defaults
  static const double defaultTaxRate = 0.0;
  static const String defaultPaymentMethod = 'Cash';

  // Supported Payment Methods
  static const List<String> paymentMethods = [
    'Cash',
    'Card',
    'Credit / Tab',
    'Online Transfer',
  ];
}
