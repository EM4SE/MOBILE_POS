import '../../../app/constants/database_constants.dart';
import '../../../core/services/database_service.dart';
import '../../models/pos_setting_model.dart';

abstract class SettingsLocalDataSource {
  Future<Map<String, String>> getAllSettings();
  Future<String?> getSetting(String key);
  Future<void> saveSetting(String key, String value);
  Future<void> saveSettings(Map<String, String> settings);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final DatabaseService _databaseService;

  SettingsLocalDataSourceImpl(this._databaseService);

  @override
  Future<Map<String, String>> getAllSettings() async {
    final results = await _databaseService.query(DatabaseConstants.tableSettings);
    final map = <String, String>{};
    for (final row in results) {
      final key = row[DatabaseConstants.colKey] as String;
      final val = row[DatabaseConstants.colValue] as String;
      map[key] = val;
    }
    return map;
  }

  @override
  Future<String?> getSetting(String key) async {
    final results = await _databaseService.query(
      DatabaseConstants.tableSettings,
      where: '${DatabaseConstants.colKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first[DatabaseConstants.colValue] as String?;
  }

  @override
  Future<void> saveSetting(String key, String value) async {
    final setting = PosSetting(key: key, value: value);
    await _databaseService.insert(DatabaseConstants.tableSettings, setting.toMap());
  }

  @override
  Future<void> saveSettings(Map<String, String> settings) async {
    await _databaseService.transaction<void>((txn) async {
      for (final entry in settings.entries) {
        final setting = PosSetting(key: entry.key, value: entry.value);
        await txn.insert(
          DatabaseConstants.tableSettings,
          setting.toMap(),
        );
      }
    });
  }
}
