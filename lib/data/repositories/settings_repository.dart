import '../datasources/local/settings_local_datasource.dart';

abstract class SettingsRepository {
  Future<Map<String, String>> getAllSettings();
  Future<String?> getSetting(String key);
  Future<void> saveSetting(String key, String value);
  Future<void> saveSettings(Map<String, String> settings);
}

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource _localDataSource;

  SettingsRepositoryImpl(this._localDataSource);

  @override
  Future<Map<String, String>> getAllSettings() {
    return _localDataSource.getAllSettings();
  }

  @override
  Future<String?> getSetting(String key) {
    return _localDataSource.getSetting(key);
  }

  @override
  Future<void> saveSetting(String key, String value) {
    return _localDataSource.saveSetting(key, value);
  }

  @override
  Future<void> saveSettings(Map<String, String> settings) {
    return _localDataSource.saveSettings(settings);
  }
}
