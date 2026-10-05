import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Handles platform-aware SQLite engine initialization (Web, Windows/Linux/macOS FFI, and Android native)
class DatabaseInitializer {
  DatabaseInitializer._();

  static bool _isInitialized = false;

  static void initializePlatform() {
    if (_isInitialized) return;

    if (kIsWeb) {
      // Browser IndexedDB-backed SQLite database factory
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop platforms FFI SQLite database factory
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    }
    _isInitialized = true;
  }
}
