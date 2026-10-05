import '../../../app/constants/database_constants.dart';
import '../../../core/services/database_service.dart';
import '../../models/user_model.dart';

abstract class UserLocalDataSource {
  Future<User?> authenticateByPin(String pin);
  Future<List<User>> getAllUsers();
  Future<User?> getUserById(int id);
  Future<int> insertUser(User user);
  Future<int> updateUser(User user);
  Future<int> deleteUser(int id);
}

class UserLocalDataSourceImpl implements UserLocalDataSource {
  final DatabaseService _databaseService;

  UserLocalDataSourceImpl(this._databaseService);

  @override
  Future<User?> authenticateByPin(String pin) async {
    final results = await _databaseService.query(
      DatabaseConstants.tableUsers,
      where: '${DatabaseConstants.colPin} = ? AND ${DatabaseConstants.colActive} = 1',
      whereArgs: [pin],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  @override
  Future<List<User>> getAllUsers() async {
    final results = await _databaseService.query(
      DatabaseConstants.tableUsers,
      orderBy: '${DatabaseConstants.colId} ASC',
    );
    return results.map(User.fromMap).toList();
  }

  @override
  Future<User?> getUserById(int id) async {
    final results = await _databaseService.query(
      DatabaseConstants.tableUsers,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  @override
  Future<int> insertUser(User user) async {
    return await _databaseService.insert(
      DatabaseConstants.tableUsers,
      user.toMap(),
    );
  }

  @override
  Future<int> updateUser(User user) async {
    return await _databaseService.update(
      DatabaseConstants.tableUsers,
      user.toMap(),
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [user.id],
    );
  }

  @override
  Future<int> deleteUser(int id) async {
    return await _databaseService.delete(
      DatabaseConstants.tableUsers,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }
}
