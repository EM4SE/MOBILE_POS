import 'package:sqflite/sqflite.dart';
import '../../app/constants/database_constants.dart';

/// Database schema definitions, tables creation, indices, and default seed data
class DatabaseMigrations {
  DatabaseMigrations._();

  static Future<void> onCreate(Database db, int version) async {
    // 1. Users table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableUsers} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colUsername} TEXT NOT NULL UNIQUE,
        ${DatabaseConstants.colDisplayName} TEXT NOT NULL,
        ${DatabaseConstants.colPin} TEXT NOT NULL,
        ${DatabaseConstants.colRole} TEXT NOT NULL DEFAULT 'CASHIER',
        ${DatabaseConstants.colActive} INTEGER NOT NULL DEFAULT 1,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL
      )
    ''');

    // 2. Products table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableProducts} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colCode} TEXT NOT NULL UNIQUE,
        ${DatabaseConstants.colBarcode} TEXT,
        ${DatabaseConstants.colIsbn} TEXT,
        ${DatabaseConstants.colDescription} TEXT NOT NULL,
        ${DatabaseConstants.colPrice} REAL NOT NULL,
        ${DatabaseConstants.colCost} REAL DEFAULT 0.0,
        ${DatabaseConstants.colActive} INTEGER NOT NULL DEFAULT 1,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL
      )
    ''');

    // 3. Customers table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCustomers} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colName} TEXT NOT NULL,
        ${DatabaseConstants.colPhone} TEXT,
        ${DatabaseConstants.colEmail} TEXT,
        ${DatabaseConstants.colAddress} TEXT,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL
      )
    ''');

    // 4. Sales table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSales} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colInvoiceNo} TEXT NOT NULL UNIQUE,
        ${DatabaseConstants.colCustomerId} INTEGER,
        ${DatabaseConstants.colCustomerName} TEXT NOT NULL,
        ${DatabaseConstants.colSubtotal} REAL NOT NULL,
        ${DatabaseConstants.colDiscount} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseConstants.colTax} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseConstants.colGrandTotal} REAL NOT NULL,
        ${DatabaseConstants.colPaidAmount} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseConstants.colChangeAmount} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseConstants.colPaymentMethod} TEXT NOT NULL DEFAULT 'Cash',
        ${DatabaseConstants.colStatus} TEXT NOT NULL DEFAULT 'COMPLETED',
        ${DatabaseConstants.colCashierName} TEXT NOT NULL,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL
      )
    ''');

    // 5. Sale Items table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSaleItems} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colSaleId} INTEGER NOT NULL,
        ${DatabaseConstants.colProductId} INTEGER,
        ${DatabaseConstants.colProductCode} TEXT NOT NULL,
        ${DatabaseConstants.colProductDescription} TEXT NOT NULL,
        ${DatabaseConstants.colQuantity} REAL NOT NULL,
        ${DatabaseConstants.colUnitPrice} REAL NOT NULL,
        ${DatabaseConstants.colUnitCost} REAL NOT NULL DEFAULT 0.0,
        discount REAL NOT NULL DEFAULT 0.0,
        ${DatabaseConstants.colLineTotal} REAL NOT NULL,
        FOREIGN KEY (${DatabaseConstants.colSaleId}) REFERENCES ${DatabaseConstants.tableSales} (${DatabaseConstants.colId}) ON DELETE CASCADE
      )
    ''');

    // 6. Settings table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSettings} (
        ${DatabaseConstants.colKey} TEXT PRIMARY KEY,
        ${DatabaseConstants.colValue} TEXT NOT NULL,
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL
      )
    ''');

    // 7. Business Days table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableBusinessDays} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colDayNumber} INTEGER NOT NULL,
        ${DatabaseConstants.colOpenedAt} TEXT NOT NULL,
        ${DatabaseConstants.colClosedAt} TEXT,
        ${DatabaseConstants.colOpenedBy} TEXT NOT NULL,
        ${DatabaseConstants.colClosedBy} TEXT,
        ${DatabaseConstants.colOpeningBalance} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseConstants.colClosingBalance} REAL DEFAULT 0.0,
        ${DatabaseConstants.colExpectedBalance} REAL DEFAULT 0.0,
        ${DatabaseConstants.colTotalSales} REAL DEFAULT 0.0,
        ${DatabaseConstants.colStatus} TEXT NOT NULL DEFAULT 'OPEN'
      )
    ''');

    // 8. Shifts table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableShifts} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colDayId} INTEGER NOT NULL,
        ${DatabaseConstants.colShiftNumber} INTEGER NOT NULL,
        ${DatabaseConstants.colOpenedAt} TEXT NOT NULL,
        ${DatabaseConstants.colClosedAt} TEXT,
        ${DatabaseConstants.colCashierUsername} TEXT NOT NULL,
        ${DatabaseConstants.colCashierName} TEXT NOT NULL,
        ${DatabaseConstants.colOpeningBalance} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseConstants.colClosingBalance} REAL DEFAULT 0.0,
        ${DatabaseConstants.colExpectedBalance} REAL DEFAULT 0.0,
        ${DatabaseConstants.colCashSales} REAL DEFAULT 0.0,
        ${DatabaseConstants.colTotalSales} REAL DEFAULT 0.0,
        ${DatabaseConstants.colPaidIn} REAL DEFAULT 0.0,
        ${DatabaseConstants.colPaidOut} REAL DEFAULT 0.0,
        ${DatabaseConstants.colCashDifference} REAL DEFAULT 0.0,
        ${DatabaseConstants.colStatus} TEXT NOT NULL DEFAULT 'OPEN',
        FOREIGN KEY (${DatabaseConstants.colDayId}) REFERENCES ${DatabaseConstants.tableBusinessDays} (${DatabaseConstants.colId}) ON DELETE CASCADE
      )
    ''');

    // 9. Exchange Vouchers table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableExchangeVouchers} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colVoucherCode} TEXT NOT NULL UNIQUE,
        ${DatabaseConstants.colCustomerId} INTEGER,
        ${DatabaseConstants.colCustomerName} TEXT,
        ${DatabaseConstants.colTotalAmount} REAL NOT NULL,
        ${DatabaseConstants.colRemainingAmount} REAL NOT NULL,
        ${DatabaseConstants.colItemsJson} TEXT NOT NULL,
        ${DatabaseConstants.colStatus} TEXT NOT NULL DEFAULT 'ACTIVE',
        ${DatabaseConstants.colRedeemedInvoiceNo} TEXT,
        ${DatabaseConstants.colCashierName} TEXT NOT NULL,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colRedeemedAt} TEXT
      )
    ''');

    // 10. Cash Movements table (Paid In / Paid Out audit trail)
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCashMovements} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colDayId} INTEGER,
        shift_id INTEGER,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        cashier_name TEXT NOT NULL,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL
      )
    ''');

    // Indices for optimal POS query performance on older hardware
    await db.execute('CREATE INDEX idx_products_code ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colCode});');
    await db.execute('CREATE INDEX idx_products_barcode ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colBarcode});');
    await db.execute('CREATE INDEX idx_products_isbn ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colIsbn});');
    await db.execute('CREATE INDEX idx_products_active ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colActive});');
    await db.execute('CREATE INDEX idx_customers_phone ON ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colPhone});');
    await db.execute('CREATE INDEX idx_sales_invoice ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colInvoiceNo});');
    await db.execute('CREATE INDEX idx_sales_status ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colStatus});');
    await db.execute('CREATE INDEX idx_sale_items_sale_id ON ${DatabaseConstants.tableSaleItems} (${DatabaseConstants.colSaleId});');
    await db.execute('CREATE INDEX idx_business_days_status ON ${DatabaseConstants.tableBusinessDays} (${DatabaseConstants.colStatus});');
    await db.execute('CREATE INDEX idx_shifts_status ON ${DatabaseConstants.tableShifts} (${DatabaseConstants.colStatus});');
    await db.execute('CREATE INDEX idx_exchange_voucher_code ON ${DatabaseConstants.tableExchangeVouchers} (${DatabaseConstants.colVoucherCode});');
    await db.execute('CREATE INDEX idx_cash_movements_shift ON ${DatabaseConstants.tableCashMovements} (shift_id);');

    // Seed Initial Data
    await _seedInitialData(db);
  }

  static Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Seed Default Admin & Cashier Users
    await db.insert(DatabaseConstants.tableUsers, {
      DatabaseConstants.colUsername: 'admin',
      DatabaseConstants.colDisplayName: 'Admin Master',
      DatabaseConstants.colPin: '1234',
      DatabaseConstants.colRole: 'ADMIN',
      DatabaseConstants.colActive: 1,
      DatabaseConstants.colCreatedAt: now,
    });

    await db.insert(DatabaseConstants.tableUsers, {
      DatabaseConstants.colUsername: 'cashier1',
      DatabaseConstants.colDisplayName: 'Cashier 01',
      DatabaseConstants.colPin: '0000',
      DatabaseConstants.colRole: 'CASHIER',
      DatabaseConstants.colActive: 1,
      DatabaseConstants.colCreatedAt: now,
    });

    // 2. Seed Default Customers (Excluding Walk-in which is default unassigned state)
    final sampleCustomers = [
      {'name': 'Hotel Royal Blue', 'phone': '0112345678', 'email': 'accounts@royalblue.lk', 'address': 'Colombo 03'},
      {'name': 'Kasun Perera', 'phone': '0771234567', 'email': 'kasun.p@gmail.com', 'address': 'No 45, Kandy Road, Kiribathgoda'},
      {'name': 'Dilshan Fernando', 'phone': '0719876543', 'email': 'dilshan.f@yahoo.com', 'address': '128 Main Street, Negombo'},
      {'name': 'Apex Enterprises Ltd', 'phone': '0115554321', 'email': 'info@apexpos.lk', 'address': 'Galle Road, Colombo 04'},
      {'name': 'Nadeeka Silva', 'phone': '0783344556', 'email': 'nadeeka.silva@outlook.com', 'address': '88 High Level Road, Nugegoda'},
      {'name': 'Maliban Distributors', 'phone': '0117788990', 'email': 'orders@maliban-dist.lk', 'address': 'Station Road, Ratmalana'},
      {'name': 'Sunimal Jayawardena', 'phone': '0752233445', 'email': 'sunimal.j@gmail.com', 'address': '24 Lake View, Kurunegala'},
      {'name': 'Ocean View Restaurant', 'phone': '0912233445', 'email': 'oceanview.galle@gmail.com', 'address': 'Rampart Street, Galle Fort'},
      {'name': 'Chathura Bandara', 'phone': '0768899001', 'email': 'chathura.b@gmail.com', 'address': 'Yakkala Road, Gampaha'},
    ];

    for (final c in sampleCustomers) {
      await db.insert(DatabaseConstants.tableCustomers, {
        DatabaseConstants.colName: c['name'],
        DatabaseConstants.colPhone: c['phone'],
        DatabaseConstants.colEmail: c['email'],
        DatabaseConstants.colAddress: c['address'],
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
      });
    }

    // 3. Seed Default POS Settings (Products are fetched dynamically from API)
    final defaultSettings = {
      'store_name': 'ONIMTA POS Terminal #1',
      'store_address': 'Main Street Commercial Center',
      'store_phone': '+94 11 234 5678',
      'currency_symbol': 'Rs. ',
      'tax_rate': '0.0',
      'printer_type': 'Thermal 80mm',
      'printer_ip': '192.168.1.100',
      'invoice_prefix': 'INV-',
    };

    for (final entry in defaultSettings.entries) {
      await db.insert(DatabaseConstants.tableSettings, {
        DatabaseConstants.colKey: entry.key,
        DatabaseConstants.colValue: entry.value,
        DatabaseConstants.colUpdatedAt: now,
      });
    }
  }

  /// Clean legacy dummy sample products (P101-P128) and ensure default customer records
  static Future<void> cleanLegacyDummyData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Clean up Walk-in Customer from customers table if it was previously inserted
    await db.delete(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.colPhone} = ? OR ${DatabaseConstants.colName} = ?',
      whereArgs: ['0770000000', 'Walk-in Customer'],
    );

    // Clean up hardcoded dummy sample product codes (P101 through P128)
    final dummyCodes = [
      'P101', 'P102', 'P103', 'P104', 'P105', 'P106', 'P107', 'P108', 'P109', 'P110',
      'P111', 'P112', 'P113', 'P114', 'P115', 'P116', 'P117', 'P118', 'P119', 'P120',
      'P121', 'P122', 'P123', 'P124', 'P125', 'P126', 'P127', 'P128'
    ];
    final placeholders = List.filled(dummyCodes.length, '?').join(',');
    await db.delete(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.colCode} IN ($placeholders)',
      whereArgs: dummyCodes,
    );

    // Ensure Customers
    final sampleCustomers = [
      {'name': 'Hotel Royal Blue', 'phone': '0112345678', 'email': 'accounts@royalblue.lk', 'address': 'Colombo 03'},
      {'name': 'Kasun Perera', 'phone': '0771234567', 'email': 'kasun.p@gmail.com', 'address': 'No 45, Kandy Road, Kiribathgoda'},
      {'name': 'Dilshan Fernando', 'phone': '0719876543', 'email': 'dilshan.f@yahoo.com', 'address': '128 Main Street, Negombo'},
      {'name': 'Apex Enterprises Ltd', 'phone': '0115554321', 'email': 'info@apexpos.lk', 'address': 'Galle Road, Colombo 04'},
      {'name': 'Nadeeka Silva', 'phone': '0783344556', 'email': 'nadeeka.silva@outlook.com', 'address': '88 High Level Road, Nugegoda'},
      {'name': 'Maliban Distributors', 'phone': '0117788990', 'email': 'orders@maliban-dist.lk', 'address': 'Station Road, Ratmalana'},
      {'name': 'Sunimal Jayawardena', 'phone': '0752233445', 'email': 'sunimal.j@gmail.com', 'address': '24 Lake View, Kurunegala'},
      {'name': 'Ocean View Restaurant', 'phone': '0912233445', 'email': 'oceanview.galle@gmail.com', 'address': 'Rampart Street, Galle Fort'},
      {'name': 'Chathura Bandara', 'phone': '0768899001', 'email': 'chathura.b@gmail.com', 'address': 'Yakkala Road, Gampaha'},
    ];

    for (final c in sampleCustomers) {
      final existing = await db.query(
        DatabaseConstants.tableCustomers,
        where: '${DatabaseConstants.colPhone} = ? OR ${DatabaseConstants.colName} = ?',
        whereArgs: [c['phone'], c['name']],
        limit: 1,
      );

      if (existing.isEmpty) {
        await db.insert(DatabaseConstants.tableCustomers, {
          DatabaseConstants.colName: c['name'],
          DatabaseConstants.colPhone: c['phone'],
          DatabaseConstants.colEmail: c['email'],
          DatabaseConstants.colAddress: c['address'],
          DatabaseConstants.colCreatedAt: now,
          DatabaseConstants.colUpdatedAt: now,
        });
      }
    }
  }

  /// Ensure columns and tables added in updates exist on previously created databases
  static Future<void> ensureSchemaUpdates(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableSaleItems})');
      final hasDiscountCol = columns.any((col) => col['name'] == 'discount');
      if (!hasDiscountCol) {
        await db.execute('ALTER TABLE ${DatabaseConstants.tableSaleItems} ADD COLUMN discount REAL NOT NULL DEFAULT 0.0');
      }
    } catch (_) {}

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableBusinessDays} (
          ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseConstants.colDayNumber} INTEGER NOT NULL,
          ${DatabaseConstants.colOpenedAt} TEXT NOT NULL,
          ${DatabaseConstants.colClosedAt} TEXT,
          ${DatabaseConstants.colOpenedBy} TEXT NOT NULL,
          ${DatabaseConstants.colClosedBy} TEXT,
          ${DatabaseConstants.colOpeningBalance} REAL NOT NULL DEFAULT 0.0,
          ${DatabaseConstants.colClosingBalance} REAL DEFAULT 0.0,
          ${DatabaseConstants.colExpectedBalance} REAL DEFAULT 0.0,
          ${DatabaseConstants.colTotalSales} REAL DEFAULT 0.0,
          ${DatabaseConstants.colStatus} TEXT NOT NULL DEFAULT 'OPEN'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableShifts} (
          ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseConstants.colDayId} INTEGER NOT NULL,
          ${DatabaseConstants.colShiftNumber} INTEGER NOT NULL,
          ${DatabaseConstants.colOpenedAt} TEXT NOT NULL,
          ${DatabaseConstants.colClosedAt} TEXT,
          ${DatabaseConstants.colCashierUsername} TEXT NOT NULL,
          ${DatabaseConstants.colCashierName} TEXT NOT NULL,
          ${DatabaseConstants.colOpeningBalance} REAL NOT NULL DEFAULT 0.0,
          ${DatabaseConstants.colClosingBalance} REAL DEFAULT 0.0,
          ${DatabaseConstants.colExpectedBalance} REAL DEFAULT 0.0,
          ${DatabaseConstants.colCashSales} REAL DEFAULT 0.0,
          ${DatabaseConstants.colTotalSales} REAL DEFAULT 0.0,
          ${DatabaseConstants.colPaidIn} REAL DEFAULT 0.0,
          ${DatabaseConstants.colPaidOut} REAL DEFAULT 0.0,
          ${DatabaseConstants.colCashDifference} REAL DEFAULT 0.0,
          ${DatabaseConstants.colStatus} TEXT NOT NULL DEFAULT 'OPEN'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableExchangeVouchers} (
          ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseConstants.colVoucherCode} TEXT NOT NULL UNIQUE,
          ${DatabaseConstants.colCustomerId} INTEGER,
          ${DatabaseConstants.colCustomerName} TEXT,
          ${DatabaseConstants.colTotalAmount} REAL NOT NULL,
          ${DatabaseConstants.colRemainingAmount} REAL NOT NULL,
          ${DatabaseConstants.colItemsJson} TEXT NOT NULL,
          ${DatabaseConstants.colStatus} TEXT NOT NULL DEFAULT 'ACTIVE',
          ${DatabaseConstants.colRedeemedInvoiceNo} TEXT,
          ${DatabaseConstants.colCashierName} TEXT NOT NULL,
          ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
          ${DatabaseConstants.colRedeemedAt} TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCashMovements} (
          ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseConstants.colDayId} INTEGER,
          shift_id INTEGER,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          reason TEXT NOT NULL,
          cashier_name TEXT NOT NULL,
          ${DatabaseConstants.colCreatedAt} TEXT NOT NULL
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_business_days_status ON ${DatabaseConstants.tableBusinessDays} (${DatabaseConstants.colStatus});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_status ON ${DatabaseConstants.tableShifts} (${DatabaseConstants.colStatus});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_exchange_voucher_code ON ${DatabaseConstants.tableExchangeVouchers} (${DatabaseConstants.colVoucherCode});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cash_movements_shift ON ${DatabaseConstants.tableCashMovements} (shift_id);');

      // Safe update for existing products table to support ISBN
      try {
        await db.execute('ALTER TABLE ${DatabaseConstants.tableProducts} ADD COLUMN ${DatabaseConstants.colIsbn} TEXT;');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_isbn ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colIsbn});');
      } catch (_) {}

      // Safe update for sales sync columns
      try {
        final salesCols = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableSales})');
        final hasIsSynced = salesCols.any((col) => col['name'] == DatabaseConstants.colIsSynced);
        if (!hasIsSynced) {
          await db.execute('ALTER TABLE ${DatabaseConstants.tableSales} ADD COLUMN ${DatabaseConstants.colIsSynced} INTEGER NOT NULL DEFAULT 0;');
          await db.execute('ALTER TABLE ${DatabaseConstants.tableSales} ADD COLUMN ${DatabaseConstants.colSyncedAt} TEXT;');
        }
      } catch (_) {}

      // Table for Sync and User Activity Audit Logs
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSyncLogs} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT NOT NULL,
            title TEXT NOT NULL,
            details TEXT,
            status TEXT NOT NULL,
            response_body TEXT,
            error_message TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_logs_action ON ${DatabaseConstants.tableSyncLogs} (action_type);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_logs_status ON ${DatabaseConstants.tableSyncLogs} (status);');
      } catch (_) {}
    } catch (_) {}
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    await ensureSchemaUpdates(db);
  }
}
