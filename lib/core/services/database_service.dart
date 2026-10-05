import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

/// Abstract service interface for low-level database operations
abstract class DatabaseService {
  Future<Database> get database;
  Future<int> insert(String table, Map<String, dynamic> values);
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]);
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs});
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs});
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action);
}

/// Concrete implementation delegating to DatabaseHelper
class DatabaseServiceImpl implements DatabaseService {
  final DatabaseHelper _dbHelper;

  DatabaseServiceImpl([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<Database> get database => _dbHelper.database;

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  @override
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    return await _dbHelper.transaction<T>(action);
  }
}
