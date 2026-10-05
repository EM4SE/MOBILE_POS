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

    // Indices for optimal POS query performance on older hardware
    await db.execute('CREATE INDEX idx_products_code ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colCode});');
    await db.execute('CREATE INDEX idx_products_barcode ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colBarcode});');
    await db.execute('CREATE INDEX idx_products_active ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colActive});');
    await db.execute('CREATE INDEX idx_customers_phone ON ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colPhone});');
    await db.execute('CREATE INDEX idx_sales_invoice ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colInvoiceNo});');
    await db.execute('CREATE INDEX idx_sales_status ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colStatus});');
    await db.execute('CREATE INDEX idx_sale_items_sale_id ON ${DatabaseConstants.tableSaleItems} (${DatabaseConstants.colSaleId});');

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

    // 2. Seed Default Walk-in Customer
    await db.insert(DatabaseConstants.tableCustomers, {
      DatabaseConstants.colName: 'Walk-in Customer',
      DatabaseConstants.colPhone: '0770000000',
      DatabaseConstants.colEmail: 'walkin@pos.local',
      DatabaseConstants.colAddress: 'Store Counter',
      DatabaseConstants.colCreatedAt: now,
      DatabaseConstants.colUpdatedAt: now,
    });

    await db.insert(DatabaseConstants.tableCustomers, {
      DatabaseConstants.colName: 'Hotel Royal Blue',
      DatabaseConstants.colPhone: '0112345678',
      DatabaseConstants.colEmail: 'accounts@royalblue.lk',
      DatabaseConstants.colAddress: 'Colombo 03',
      DatabaseConstants.colCreatedAt: now,
      DatabaseConstants.colUpdatedAt: now,
    });

    // 3. Seed Standard POS Products for rapid testing & live use
    final sampleProducts = [
      {'code': 'P101', 'barcode': '890103001', 'desc': 'Coca Cola 400ml', 'price': 250.0, 'cost': 180.0},
      {'code': 'P102', 'barcode': '890103002', 'desc': 'Special Lunch Buffet', 'price': 850.0, 'cost': 520.0},
      {'code': 'P103', 'barcode': '890103003', 'desc': 'Espresso Double Shot', 'price': 450.0, 'cost': 150.0},
      {'code': 'P104', 'barcode': '890103004', 'desc': 'Club Sandwich Supreme', 'price': 950.0, 'cost': 600.0},
      {'code': 'P105', 'barcode': '890103005', 'desc': 'Mineral Water 500ml', 'price': 100.0, 'cost': 50.0},
      {'code': 'P106', 'barcode': '890103006', 'desc': 'Crispy Chicken Burger', 'price': 1200.0, 'cost': 750.0},
      {'code': 'P107', 'barcode': '890103007', 'desc': 'Iced Caramel Macchiato', 'price': 650.0, 'cost': 320.0},
      {'code': 'P108', 'barcode': '890103008', 'desc': 'French Fries Large', 'price': 550.0, 'cost': 280.0},
      {'code': 'P109', 'barcode': '4791034017015', 'desc': 'Munchee Lemonpuff', 'price': 180.0, 'cost': 140.0},
    ];

    for (final p in sampleProducts) {
      await db.insert(DatabaseConstants.tableProducts, {
        DatabaseConstants.colCode: p['code'],
        DatabaseConstants.colBarcode: p['barcode'],
        DatabaseConstants.colDescription: p['desc'],
        DatabaseConstants.colPrice: p['price'],
        DatabaseConstants.colCost: p['cost'],
        DatabaseConstants.colActive: 1,
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // 4. Seed Default POS Settings
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

  /// Ensure essential demo / standard products exist in current database
  static Future<void> ensureSampleProducts(Database db) async {
    final now = DateTime.now().toIso8601String();
    final sampleProducts = [
      {'code': 'P101', 'barcode': '890103001', 'desc': 'Coca Cola 400ml', 'price': 250.0, 'cost': 180.0},
      {'code': 'P102', 'barcode': '890103002', 'desc': 'Special Lunch Buffet', 'price': 850.0, 'cost': 520.0},
      {'code': 'P103', 'barcode': '890103003', 'desc': 'Espresso Double Shot', 'price': 450.0, 'cost': 150.0},
      {'code': 'P104', 'barcode': '890103004', 'desc': 'Club Sandwich Supreme', 'price': 950.0, 'cost': 600.0},
      {'code': 'P105', 'barcode': '890103005', 'desc': 'Mineral Water 500ml', 'price': 100.0, 'cost': 50.0},
      {'code': 'P106', 'barcode': '890103006', 'desc': 'Crispy Chicken Burger', 'price': 1200.0, 'cost': 750.0},
      {'code': 'P107', 'barcode': '890103007', 'desc': 'Iced Caramel Macchiato', 'price': 650.0, 'cost': 320.0},
      {'code': 'P108', 'barcode': '890103008', 'desc': 'French Fries Large', 'price': 550.0, 'cost': 280.0},
      {'code': 'P109', 'barcode': '4791034017015', 'desc': 'Munchee Lemonpuff', 'price': 180.0, 'cost': 140.0},
    ];

    for (final p in sampleProducts) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO ${DatabaseConstants.tableProducts}
        (${DatabaseConstants.colCode}, ${DatabaseConstants.colBarcode}, ${DatabaseConstants.colDescription}, ${DatabaseConstants.colPrice}, ${DatabaseConstants.colCost}, ${DatabaseConstants.colActive}, ${DatabaseConstants.colCreatedAt}, ${DatabaseConstants.colUpdatedAt})
        VALUES (?, ?, ?, ?, ?, 1, ?, ?)
      ''', [p['code'], p['barcode'], p['desc'], p['price'], p['cost'], now, now]);

      // If already exists by code/barcode, update to ensure barcode is accurate
      await db.rawUpdate('''
        UPDATE ${DatabaseConstants.tableProducts}
        SET ${DatabaseConstants.colBarcode} = ?, ${DatabaseConstants.colDescription} = ?, ${DatabaseConstants.colPrice} = ?
        WHERE ${DatabaseConstants.colBarcode} = ? OR ${DatabaseConstants.colCode} = ?
      ''', [p['barcode'], p['desc'], p['price'], p['barcode'], p['code']]);
    }
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Schema migration steps for future versions
  }
}
