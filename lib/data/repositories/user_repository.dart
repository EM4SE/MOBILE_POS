import '../datasources/local/user_local_datasource.dart';
import '../datasources/remote/user_remote_datasource.dart';
import '../models/user_model.dart';
import 'sync_log_repository.dart';

abstract class UserRepository {
  Future<User?> authenticateByPin(String pin);
  Future<List<User>> getUsersByPin(String pin);
  Future<List<User>> getAllUsers();
  Future<User?> getUserById(int id);
  Future<int> insertUser(User user);
  Future<int> updateUser(User user);
  Future<int> deleteUser(int id);
  Future<List<User>> fetchAndSyncCashiers({String? baseUrl});
}

class UserRepositoryImpl implements UserRepository {
  final UserLocalDataSource _localDataSource;
  final UserRemoteDataSource? _remoteDataSource;
  final SyncLogRepository? _syncLogRepository;

  UserRepositoryImpl(
    this._localDataSource, [
    this._remoteDataSource,
    this._syncLogRepository,
  ]);

  @override
  Future<User?> authenticateByPin(String pin) {
    return _localDataSource.authenticateByPin(pin);
  }

  @override
  Future<List<User>> getUsersByPin(String pin) {
    return _localDataSource.getUsersByPin(pin);
  }

  @override
  Future<List<User>> getAllUsers() {
    return _localDataSource.getAllUsers();
  }

  @override
  Future<User?> getUserById(int id) {
    return _localDataSource.getUserById(id);
  }

  @override
  Future<int> insertUser(User user) {
    return _localDataSource.insertUser(user);
  }

  @override
  Future<int> updateUser(User user) {
    return _localDataSource.updateUser(user);
  }

  @override
  Future<int> deleteUser(int id) {
    return _localDataSource.deleteUser(id);
  }

  @override
  Future<List<User>> fetchAndSyncCashiers({String? baseUrl}) async {
    if (_remoteDataSource == null) {
      return _localDataSource.getAllUsers();
    }

    try {
      final remoteCashiers = await _remoteDataSource.fetchCashiersFromApi(baseUrl: baseUrl);
      if (remoteCashiers.isNotEmpty) {
        await _localDataSource.syncUsersFromRemote(remoteCashiers);
      }
      await _syncLogRepository?.logAction(
        actionType: 'USER_SYNC',
        title: 'Cashiers Synced from ERP (Iid 8)',
        details: 'Successfully loaded ${remoteCashiers.length} cashiers from ERP server.',
        status: 'SUCCESS',
      );
      return await _localDataSource.getAllUsers();
    } catch (e) {
      await _syncLogRepository?.logAction(
        actionType: 'USER_SYNC',
        title: 'Cashier Sync Failed (Iid 8)',
        details: 'Failed to load cashiers from ERP. Error: $e',
        status: 'FAILED',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
}

