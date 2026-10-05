import 'package:flutter/foundation.dart';
import '../../../data/repositories/settings_repository.dart';

/// Controller managing POS terminal preferences, receipt printer settings, and store profile
class SettingsController extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  Map<String, String> _settings = {};
  bool _isLoading = false;
  String? _errorMessage;

  SettingsController(this._settingsRepository);

  Map<String, String> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get storeName => _settings['store_name'] ?? 'ONIMTA POS Terminal #1';
  String get storeAddress => _settings['store_address'] ?? 'Main Street Commercial Center';
  String get storePhone => _settings['store_phone'] ?? '+94 11 234 5678';
  String get currencySymbol => _settings['currency_symbol'] ?? 'Rs. ';
  String get taxRate => _settings['tax_rate'] ?? '0.0';
  String get printerType => _settings['printer_type'] ?? 'Thermal 80mm';
  String get printerIp => _settings['printer_ip'] ?? '192.168.1.100';
  String get invoicePrefix => _settings['invoice_prefix'] ?? 'INV-';

  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _settingsRepository.getAllSettings();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load settings: $e';
      notifyListeners();
    }
  }

  Future<bool> updateSetting(String key, String value) async {
    try {
      await _settingsRepository.saveSetting(key, value);
      _settings[key] = value;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save setting: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSettings(Map<String, String> newSettings) async {
    try {
      await _settingsRepository.saveSettings(newSettings);
      _settings.addAll(newSettings);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save settings: $e';
      notifyListeners();
      return false;
    }
  }
}
