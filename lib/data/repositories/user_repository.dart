import '../datasources/local/user_local_datasource.dart';
import '../models/user_model.dart';

abstract class UserRepository {
  Future<User?> authenticateByPin(String pin);
  Future<List<User>> getAllUsers();
  Future<User?> getUserById(int id);
  Future<int> insertUser(User user);
  Future<int> updateUser(User user);
  Future<int> deleteUser(int id);
}

class UserRepositoryImpl implements UserRepository {
  final UserLocalDataSource _localDataSource;

  UserRepositoryImpl(this._localDataSource);

  @override
  Future<User?> authenticateByPin(String pin) {
    return _localDataSource.authenticateByPin(pin);
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
}
