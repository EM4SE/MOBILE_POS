import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;
import '../../app/constants/database_constants.dart';
import '../exceptions/app_exceptions.dart';
import 'database_initializer.dart';
import 'database_migrations.dart';

/// DatabaseHelper manages the SQLite database lifecycle, connection pooling, and transactions across Android, Web, and Desktop
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      DatabaseInitializer.initializePlatform();

      String dbPath;
      if (kIsWeb) {
        dbPath = DatabaseConstants.databaseName;
      } else {
        final databasesPath = await getDatabasesPath();
        dbPath = p.join(databasesPath, DatabaseConstants.databaseName);
      }

      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: DatabaseConstants.databaseVersion,
          onCreate: DatabaseMigrations.onCreate,
          onUpgrade: DatabaseMigrations.onUpgrade,
          onOpen: (db) async {
            await DatabaseMigrations.ensureSampleProducts(db);
          },
        ),
      );
      return db;
    } catch (e, stack) {
      throw DatabaseException('Failed to initialize SQLite database: $e', stack.toString());
    }
  }

  /// Run multiple operations inside an atomic SQLite transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction<T>(action);
  }

  /// Close database connection safely
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
