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

    // Indices for optimal POS query performance on older hardware
    await db.execute('CREATE INDEX idx_products_code ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colCode});');
    await db.execute('CREATE INDEX idx_products_barcode ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colBarcode});');
    await db.execute('CREATE INDEX idx_products_active ON ${DatabaseConstants.tableProducts} (${DatabaseConstants.colActive});');
    await db.execute('CREATE INDEX idx_customers_phone ON ${DatabaseConstants.tableCustomers} (${DatabaseConstants.colPhone});');
    await db.execute('CREATE INDEX idx_sales_invoice ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colInvoiceNo});');
    await db.execute('CREATE INDEX idx_sales_status ON ${DatabaseConstants.tableSales} (${DatabaseConstants.colStatus});');
    await db.execute('CREATE INDEX idx_sale_items_sale_id ON ${DatabaseConstants.tableSaleItems} (${DatabaseConstants.colSaleId});');
    await db.execute('CREATE INDEX idx_business_days_status ON ${DatabaseConstants.tableBusinessDays} (${DatabaseConstants.colStatus});');
    await db.execute('CREATE INDEX idx_shifts_status ON ${DatabaseConstants.tableShifts} (${DatabaseConstants.colStatus});');
    await db.execute('CREATE INDEX idx_exchange_voucher_code ON ${DatabaseConstants.tableExchangeVouchers} (${DatabaseConstants.colVoucherCode});');

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
      {'code': 'P109', 'barcode': '4791034017015', 'desc': 'Munchee Lemonpuff 200g', 'price': 180.0, 'cost': 140.0},
      {'code': 'P110', 'barcode': '890103010', 'desc': 'Red Bull Energy Drink 250ml', 'price': 650.0, 'cost': 450.0},
      {'code': 'P111', 'barcode': '890103011', 'desc': 'Sprite 400ml Bottle', 'price': 250.0, 'cost': 180.0},
      {'code': 'P112', 'barcode': '890103012', 'desc': 'Fresh Orange Juice 350ml', 'price': 480.0, 'cost': 250.0},
      {'code': 'P113', 'barcode': '890103013', 'desc': 'Iced Coffee Milk Blend', 'price': 420.0, 'cost': 220.0},
      {'code': 'P114', 'barcode': '890103014', 'desc': 'Hot Cappuccino Cup', 'price': 520.0, 'cost': 260.0},
      {'code': 'P115', 'barcode': '890103015', 'desc': 'Beef Cheese Burger', 'price': 1350.0, 'cost': 850.0},
      {'code': 'P116', 'barcode': '890103016', 'desc': 'Spicy Chicken Submarine', 'price': 1100.0, 'cost': 680.0},
      {'code': 'P117', 'barcode': '890103017', 'desc': 'Chicken Kottu Rotti Full', 'price': 980.0, 'cost': 580.0},
      {'code': 'P118', 'barcode': '890103018', 'desc': 'Veggie Cheese Pizza Slice', 'price': 620.0, 'cost': 350.0},
      {'code': 'P119', 'barcode': '890103019', 'desc': 'Fried Chicken Rice Large', 'price': 920.0, 'cost': 550.0},
      {'code': 'P120', 'barcode': '890103020', 'desc': 'Chocolate Fudge Brownie', 'price': 380.0, 'cost': 190.0},
      {'code': 'P121', 'barcode': '890103021', 'desc': 'Glazed Cinnamon Donut', 'price': 220.0, 'cost': 110.0},
      {'code': 'P122', 'barcode': '890103022', 'desc': 'Spicy Fish Bun', 'price': 120.0, 'cost': 70.0},
      {'code': 'P123', 'barcode': '890103023', 'desc': 'Chicken Sausage Roll', 'price': 150.0, 'cost': 85.0},
      {'code': 'P124', 'barcode': '4791034017022', 'desc': 'Munchee Super Cream Cracker', 'price': 220.0, 'cost': 160.0},
      {'code': 'P125', 'barcode': '890103025', 'desc': 'Anchor Pure Butter 200g', 'price': 890.0, 'cost': 720.0},
      {'code': 'P126', 'barcode': '890103026', 'desc': 'Highland Fresh Milk 1L', 'price': 460.0, 'cost': 380.0},
      {'code': 'P127', 'barcode': '890103027', 'desc': 'Watawala Ceylon Tea 200g', 'price': 380.0, 'cost': 290.0},
      {'code': 'P128', 'barcode': '890103028', 'desc': 'Keells White Sugar 1kg', 'price': 310.0, 'cost': 260.0},
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

  /// Ensure essential demo / standard products & customers exist in current database
  static Future<void> ensureSampleProducts(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Clean up Walk-in Customer from customers table if it was previously inserted
    await db.delete(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.colPhone} = ? OR ${DatabaseConstants.colName} = ?',
      whereArgs: ['0770000000', 'Walk-in Customer'],
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

    // Ensure Products
    final sampleProducts = [
      {'code': 'P101', 'barcode': '890103001', 'desc': 'Coca Cola 400ml', 'price': 250.0, 'cost': 180.0},
      {'code': 'P102', 'barcode': '890103002', 'desc': 'Special Lunch Buffet', 'price': 850.0, 'cost': 520.0},
      {'code': 'P103', 'barcode': '890103003', 'desc': 'Espresso Double Shot', 'price': 450.0, 'cost': 150.0},
      {'code': 'P104', 'barcode': '890103004', 'desc': 'Club Sandwich Supreme', 'price': 950.0, 'cost': 600.0},
      {'code': 'P105', 'barcode': '890103005', 'desc': 'Mineral Water 500ml', 'price': 100.0, 'cost': 50.0},
      {'code': 'P106', 'barcode': '890103006', 'desc': 'Crispy Chicken Burger', 'price': 1200.0, 'cost': 750.0},
      {'code': 'P107', 'barcode': '890103007', 'desc': 'Iced Caramel Macchiato', 'price': 650.0, 'cost': 320.0},
      {'code': 'P108', 'barcode': '890103008', 'desc': 'French Fries Large', 'price': 550.0, 'cost': 280.0},
      {'code': 'P109', 'barcode': '4791034017015', 'desc': 'Munchee Lemonpuff 200g', 'price': 180.0, 'cost': 140.0},
      {'code': 'P110', 'barcode': '890103010', 'desc': 'Red Bull Energy Drink 250ml', 'price': 650.0, 'cost': 450.0},
      {'code': 'P111', 'barcode': '890103011', 'desc': 'Sprite 400ml Bottle', 'price': 250.0, 'cost': 180.0},
      {'code': 'P112', 'barcode': '890103012', 'desc': 'Fresh Orange Juice 350ml', 'price': 480.0, 'cost': 250.0},
      {'code': 'P113', 'barcode': '890103013', 'desc': 'Iced Coffee Milk Blend', 'price': 420.0, 'cost': 220.0},
      {'code': 'P114', 'barcode': '890103014', 'desc': 'Hot Cappuccino Cup', 'price': 520.0, 'cost': 260.0},
      {'code': 'P115', 'barcode': '890103015', 'desc': 'Beef Cheese Burger', 'price': 1350.0, 'cost': 850.0},
      {'code': 'P116', 'barcode': '890103016', 'desc': 'Spicy Chicken Submarine', 'price': 1100.0, 'cost': 680.0},
      {'code': 'P117', 'barcode': '890103017', 'desc': 'Chicken Kottu Rotti Full', 'price': 980.0, 'cost': 580.0},
      {'code': 'P118', 'barcode': '890103018', 'desc': 'Veggie Cheese Pizza Slice', 'price': 620.0, 'cost': 350.0},
      {'code': 'P119', 'barcode': '890103019', 'desc': 'Fried Chicken Rice Large', 'price': 920.0, 'cost': 550.0},
      {'code': 'P120', 'barcode': '890103020', 'desc': 'Chocolate Fudge Brownie', 'price': 380.0, 'cost': 190.0},
      {'code': 'P121', 'barcode': '890103021', 'desc': 'Glazed Cinnamon Donut', 'price': 220.0, 'cost': 110.0},
      {'code': 'P122', 'barcode': '890103022', 'desc': 'Spicy Fish Bun', 'price': 120.0, 'cost': 70.0},
      {'code': 'P123', 'barcode': '890103023', 'desc': 'Chicken Sausage Roll', 'price': 150.0, 'cost': 85.0},
      {'code': 'P124', 'barcode': '4791034017022', 'desc': 'Munchee Super Cream Cracker', 'price': 220.0, 'cost': 160.0},
      {'code': 'P125', 'barcode': '890103025', 'desc': 'Anchor Pure Butter 200g', 'price': 890.0, 'cost': 720.0},
      {'code': 'P126', 'barcode': '890103026', 'desc': 'Highland Fresh Milk 1L', 'price': 460.0, 'cost': 380.0},
      {'code': 'P127', 'barcode': '890103027', 'desc': 'Watawala Ceylon Tea 200g', 'price': 380.0, 'cost': 290.0},
      {'code': 'P128', 'barcode': '890103028', 'desc': 'Keells White Sugar 1kg', 'price': 310.0, 'cost': 260.0},
    ];

    for (final p in sampleProducts) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO ${DatabaseConstants.tableProducts}
        (${DatabaseConstants.colCode}, ${DatabaseConstants.colBarcode}, ${DatabaseConstants.colDescription}, ${DatabaseConstants.colPrice}, ${DatabaseConstants.colCost}, ${DatabaseConstants.colActive}, ${DatabaseConstants.colCreatedAt}, ${DatabaseConstants.colUpdatedAt})
        VALUES (?, ?, ?, ?, ?, 1, ?, ?)
      ''', [p['code'], p['barcode'], p['desc'], p['price'], p['cost'], now, now]);

      // If already exists by code/barcode, update to ensure barcode and descriptions are accurate
      await db.rawUpdate('''
        UPDATE ${DatabaseConstants.tableProducts}
        SET ${DatabaseConstants.colBarcode} = ?, ${DatabaseConstants.colDescription} = ?, ${DatabaseConstants.colPrice} = ?, ${DatabaseConstants.colCost} = ?
        WHERE ${DatabaseConstants.colBarcode} = ? OR ${DatabaseConstants.colCode} = ?
      ''', [p['barcode'], p['desc'], p['price'], p['cost'], p['barcode'], p['code']]);
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

      await db.execute('CREATE INDEX IF NOT EXISTS idx_business_days_status ON ${DatabaseConstants.tableBusinessDays} (${DatabaseConstants.colStatus});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_status ON ${DatabaseConstants.tableShifts} (${DatabaseConstants.colStatus});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_exchange_voucher_code ON ${DatabaseConstants.tableExchangeVouchers} (${DatabaseConstants.colVoucherCode});');
    } catch (_) {}
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    await ensureSchemaUpdates(db);
  }
}
