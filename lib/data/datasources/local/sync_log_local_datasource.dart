import '../../../app/constants/database_constants.dart';
import '../../../core/services/database_service.dart';
import '../../models/sync_activity_log_model.dart';

abstract class SyncLogLocalDataSource {
  Future<int> insertLog(SyncActivityLog log);
  Future<List<SyncActivityLog>> getLogs({
    String? actionType,
    String? status,
    int? limit,
    int? offset,
  });
  Future<int> getLogsCount({String? status});
  Future<int> clearOldLogs({int keepDays = 30});
  Future<int> clearAllLogs();
}

class SyncLogLocalDataSourceImpl implements SyncLogLocalDataSource {
  final DatabaseService _databaseService;

  SyncLogLocalDataSourceImpl(this._databaseService);

  @override
  Future<int> insertLog(SyncActivityLog log) async {
    return await _databaseService.insert(
      DatabaseConstants.tableSyncLogs,
      log.toMap(),
    );
  }

  @override
  Future<List<SyncActivityLog>> getLogs({
    String? actionType,
    String? status,
    int? limit = 100,
    int? offset = 0,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (actionType != null && actionType.isNotEmpty && actionType != 'ALL') {
      whereClauses.add('${DatabaseConstants.colLogActionType} = ?');
      whereArgs.add(actionType);
    }

    if (status != null && status.isNotEmpty && status != 'ALL') {
      whereClauses.add('${DatabaseConstants.colLogStatus} = ?');
      whereArgs.add(status);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await _databaseService.query(
      DatabaseConstants.tableSyncLogs,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '${DatabaseConstants.colId} DESC',
      limit: limit,
      offset: offset,
    );

    return results.map(SyncActivityLog.fromMap).toList();
  }

  @override
  Future<int> getLogsCount({String? status}) async {
    String query = 'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableSyncLogs}';
    List<Object?> args = [];
    if (status != null && status.isNotEmpty && status != 'ALL') {
      query += ' WHERE ${DatabaseConstants.colLogStatus} = ?';
      args.add(status);
    }

    final results = await _databaseService.rawQuery(query, args);
    if (results.isNotEmpty && results.first['count'] != null) {
      return (results.first['count'] as num).toInt();
    }
    return 0;
  }

  @override
  Future<int> clearOldLogs({int keepDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays)).toIso8601String();
    return await _databaseService.delete(
      DatabaseConstants.tableSyncLogs,
      where: '${DatabaseConstants.colCreatedAt} < ?',
      whereArgs: [cutoff],
    );
  }

  @override
  Future<int> clearAllLogs() async {
    return await _databaseService.delete(DatabaseConstants.tableSyncLogs);
  }
}
