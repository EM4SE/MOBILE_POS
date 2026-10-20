import 'dart:convert';
import '../datasources/local/sync_log_local_datasource.dart';
import '../models/sync_activity_log_model.dart';

abstract class SyncLogRepository {
  Future<int> logAction({
    required String actionType,
    required String title,
    String? details,
    required String status,
    dynamic responseBody,
    String? errorMessage,
  });

  Future<List<SyncActivityLog>> getLogs({
    String? actionType,
    String? status,
    int? limit,
    int? offset,
  });

  Future<Map<String, int>> getLogStats();

  Future<int> clearAllLogs();
}

class SyncLogRepositoryImpl implements SyncLogRepository {
  final SyncLogLocalDataSource _localDataSource;

  SyncLogRepositoryImpl(this._localDataSource);

  @override
  Future<int> logAction({
    required String actionType,
    required String title,
    String? details,
    required String status,
    dynamic responseBody,
    String? errorMessage,
  }) async {
    String? serializedResponse;
    if (responseBody != null) {
      if (responseBody is String) {
        serializedResponse = responseBody;
      } else {
        try {
          serializedResponse = jsonEncode(responseBody);
        } catch (_) {
          serializedResponse = responseBody.toString();
        }
      }
    }

    final log = SyncActivityLog(
      actionType: actionType,
      title: title,
      details: details,
      status: status,
      responseBody: serializedResponse,
      errorMessage: errorMessage,
      createdAt: DateTime.now().toIso8601String(),
    );

    return await _localDataSource.insertLog(log);
  }

  @override
  Future<List<SyncActivityLog>> getLogs({
    String? actionType,
    String? status,
    int? limit = 100,
    int? offset = 0,
  }) {
    return _localDataSource.getLogs(
      actionType: actionType,
      status: status,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Map<String, int>> getLogStats() async {
    final total = await _localDataSource.getLogsCount();
    final success = await _localDataSource.getLogsCount(status: 'SUCCESS');
    final failed = await _localDataSource.getLogsCount(status: 'FAILED');
    final pending = await _localDataSource.getLogsCount(status: 'PENDING');

    return {
      'total': total,
      'success': success,
      'failed': failed,
      'pending': pending,
    };
  }

  @override
  Future<int> clearAllLogs() {
    return _localDataSource.clearAllLogs();
  }
}
