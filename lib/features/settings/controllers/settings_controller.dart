import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/printer_service.dart';
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
  String get printerType => _settings['printer_type'] ?? 'Thermal 58mm';
  String get printerIp => _settings['printer_ip'] ?? '192.168.1.100';
  String get invoicePrefix => _settings['invoice_prefix'] ?? 'INV-';
  String get selectedDevice => _settings['selected_device'] ?? 'NEXGO_N5';
  String get apiBaseUrl => _settings['api_base_url']?.trim().isNotEmpty == true
      ? _settings['api_base_url']!.trim()
      : ApiService.defaultBaseUrl;

  bool get isCustomApiBaseUrl =>
      _settings['api_base_url']?.trim().isNotEmpty == true &&
      _settings['api_base_url']!.trim() != ApiService.defaultBaseUrl;

  String get selectedDeviceDisplayName {
    switch (selectedDevice) {
      case 'DBL_Z93':
        return 'DBL Z93 Smart POS (80mm Printer)';
      case 'DBL_Z92':
        return 'DBL Z92 Smart POS (ZCS SDK)';
      case 'WPOS_3':
        return 'W-POS 3 (Wiseasy SDK)';
      case 'NEXGO_N5':
        return 'NEXGO N5 (Nexgo SDK)';
      case 'AUTO':
        return 'Auto-Detect Hardware';
      default:
        return selectedDevice;
    }
  }

  String get printerFont => _settings['printer_font'] ?? 'MONOSPACE';

  String get printerFontDisplayName {
    switch (printerFont.toUpperCase()) {
      case 'SANS_SERIF':
        return 'Sans-Serif (Modern / Clean)';
      case 'SERIF':
        return 'Serif (Classic / Elegant)';
      case 'DEFAULT_BOLD':
        return 'Default Bold (High Contrast)';
      case 'DEFAULT':
        return 'Standard System Default';
      case 'MONOSPACE':
      default:
        return 'Monospace (Standard POS Alignment)';
    }
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _settingsRepository.getAllSettings();
      _isLoading = false;
      PrinterService.setSelectedDevice(selectedDevice);
      PrinterService.setPrinterFont(printerFont);
      if (_settings.containsKey('api_base_url')) {
        ApiService.setBaseUrl(_settings['api_base_url']);
      } else {
        ApiService.setBaseUrl(ApiService.defaultBaseUrl);
      }
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
      if (key == 'selected_device') {
        PrinterService.setSelectedDevice(value);
      } else if (key == 'printer_font') {
        PrinterService.setPrinterFont(value);
      } else if (key == 'api_base_url') {
        ApiService.setBaseUrl(value);
      }
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
      if (newSettings.containsKey('selected_device')) {
        PrinterService.setSelectedDevice(newSettings['selected_device']!);
      }
      if (newSettings.containsKey('printer_font')) {
        PrinterService.setPrinterFont(newSettings['printer_font']!);
      }
      if (newSettings.containsKey('api_base_url')) {
        ApiService.setBaseUrl(newSettings['api_base_url']!);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save settings: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetApiBaseUrl() async {
    return updateSetting('api_base_url', ApiService.defaultBaseUrl);
  }
}
