import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/exceptions/app_exceptions.dart';
import 'package:mobile_pos/core/services/authentication_service.dart';
import 'package:mobile_pos/core/services/log_excel_export_service.dart';
import 'package:mobile_pos/core/services/shift_service.dart';
import 'package:mobile_pos/data/datasources/local/shift_local_datasource.dart';
import 'package:mobile_pos/data/models/business_day_model.dart';
import 'package:mobile_pos/data/models/customer_model.dart';
import 'package:mobile_pos/data/models/product_model.dart';
import 'package:mobile_pos/data/models/reports_model.dart';
import 'package:mobile_pos/data/models/sale_item_model.dart';
import 'package:mobile_pos/data/models/sale_model.dart';
import 'package:mobile_pos/data/models/shift_model.dart';
import 'package:mobile_pos/data/models/sync_activity_log_model.dart';
import 'package:mobile_pos/data/models/user_model.dart';
import 'package:mobile_pos/data/repositories/customer_repository.dart';
import 'package:mobile_pos/data/repositories/product_repository.dart';
import 'package:mobile_pos/data/repositories/sales_repository.dart';
import 'package:mobile_pos/data/repositories/sync_log_repository.dart';
import 'package:mobile_pos/data/repositories/user_repository.dart';
import 'package:mobile_pos/features/authentication/controllers/login_controller.dart';
import 'package:mobile_pos/features/authentication/screens/login_screen.dart';
import 'package:mobile_pos/features/pos/controllers/pos_controller.dart';

class _FakeUserRepository implements UserRepository {
  final List<User> users;
  _FakeUserRepository(this.users);

  @override
  Future<User?> authenticateByPin(String pin) async =>
      users.where((u) => u.pin == pin && u.active).firstOrNull;

  @override
  Future<List<User>> getUsersByPin(String pin) async =>
      users.where((u) => u.pin == pin).toList();

  @override
  Future<List<User>> getAllUsers() async => users;

  @override
  Future<User?> getUserById(int id) async =>
      users.where((u) => u.id == id).firstOrNull;

  @override
  Future<int> insertUser(User user) async => 1;

  @override
  Future<int> updateUser(User user) async => 1;

  @override
  Future<int> deleteUser(int id) async => 1;

  @override
  Future<List<User>> fetchAndSyncCashiers({String? baseUrl}) async => users;
}

class _InMemorySyncLogRepository implements SyncLogRepository {
  final List<SyncActivityLog> _logs = [];
  int? lastRequestedLimit = -1;

  List<SyncActivityLog> get allLogs => List.unmodifiable(_logs);

  @override
  Future<int> clearAllLogs() async {
    _logs.clear();
    return 1;
  }

  @override
  Future<Map<String, int>> getLogStats() async => {'total': _logs.length};

  @override
  Future<List<SyncActivityLog>> getLogs({
    String? actionType,
    String? status,
    int? limit = 100,
    int? offset = 0,
  }) async {
    lastRequestedLimit = limit;
    Iterable<SyncActivityLog> result = _logs.reversed;
    if (actionType != null && actionType != 'ALL') {
      result = result.where((l) => l.actionType == actionType);
    }
    if (status != null && status != 'ALL') {
      result = result.where((l) => l.status == status);
    }
    if (offset != null && offset > 0) {
      result = result.skip(offset);
    }
    if (limit != null) {
      result = result.take(limit);
    }
    return result.toList();
  }

  @override
  Future<int> logAction({
    required String actionType,
    required String title,
    String? details,
    required String status,
    responseBody,
    String? errorMessage,
  }) async {
    final id = _logs.length + 1;
    _logs.add(
      SyncActivityLog(
        id: id,
        actionType: actionType,
        title: title,
        details: details,
        status: status,
        responseBody: responseBody?.toString(),
        errorMessage: errorMessage,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    return id;
  }
}

class _FakeSalesRepository implements SalesRepository {
  final List<Sale> sales = [];
  int _seq = 1;

  @override
  Future<int> deleteSale(int saleId) async {
    sales.removeWhere((s) => s.id == saleId);
    return 1;
  }

  @override
  Future<String> generateNextInvoiceNumber({String prefix = ''}) async =>
      '${prefix}INV-${(_seq++).toString().padLeft(4, '0')}';

  @override
  Future<List<ItemWiseSaleReportItem>> getItemWiseSalesReport({String? dateFilter}) async => [];

  @override
  Future<Sale?> getSaleById(int id) async => sales.where((s) => s.id == id).firstOrNull;

  @override
  Future<Sale?> getSaleByInvoiceNo(String invoiceNo) async =>
      sales.where((s) => s.invoiceNo == invoiceNo).firstOrNull;

  @override
  Future<List<SaleItem>> getSaleItems(int saleId) async => [];

  @override
  Future<List<Sale>> getSales({String? status, int? limit, int? offset}) async {
    if (status == null) return List.of(sales);
    return sales.where((s) => s.status == status).toList();
  }

  @override
  Future<double> getTodayTotalSales() async => 0.0;

  @override
  Future<TotalSalesReportData> getTotalSalesReport({String? dateFilter}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Sale>> getUnsyncedSales() async => [];

  @override
  Future<int> insertSaleWithItems(Sale sale, List<SaleItem> items) async {
    final id = sales.length + 1;
    sales.add(sale.copyWith(id: id, items: List.of(items)));
    return id;
  }

  @override
  Future<int> markSaleSynced(int saleId, String syncedAt) async => 1;

  @override
  Future<int> updateSaleStatus(int saleId, String status) async => 1;
}

class _FakeProductRepository implements ProductRepository {
  @override
  Future<int> countProducts({String? searchQuery, bool onlyActive = true}) async => 0;
  @override
  Future<int> deleteProduct(int id) async => 1;
  @override
  Future<Product?> fetchAndCacheProductByCode(String code, {String? baseUrl}) async => null;
  @override
  Future<Product?> getProductByBarcode(String barcode) async => null;
  @override
  Future<Product?> getProductByCode(String code) async => null;
  @override
  Future<Product?> getProductById(int id) async => null;
  @override
  Future<List<Product>> getProducts({String? searchQuery, bool onlyActive = true, int? limit, int? offset}) async => [];
  @override
  Future<int> insertProduct(Product product) async => 1;
  @override
  Future<int> syncProductsFromApi({String? baseUrl, void Function(int count, String status)? onProgress}) async => 0;
  @override
  Future<int> syncQuickProductsFromApi({String? baseUrl}) async => 0;
  @override
  Future<int> updateProduct(Product product) async => 1;
}

class _FakeCustomerRepository implements CustomerRepository {
  @override
  Future<int> countCustomers({String? searchQuery}) async => 0;
  @override
  Future<int> deleteCustomer(int id) async => 1;
  @override
  Future<Customer?> getCustomerById(int id) async => null;
  @override
  Future<List<Customer>> getCustomers({String? searchQuery, int? limit, int? offset}) async => [];
  @override
  Future<int> insertCustomer(Customer customer) async => 1;
  @override
  Future<int> updateCustomer(Customer customer) async => 1;
}

class _FakeShiftService implements ShiftService {
  final ValueNotifier<BusinessDay?> _day = ValueNotifier(null);
  final ValueNotifier<Shift?> _shift = ValueNotifier(null);

  @override
  ValueListenable<BusinessDay?> get activeDay => _day;
  @override
  ValueListenable<Shift?> get activeShift => _shift;
  @override
  bool get hasActiveDay => false;
  @override
  bool get hasActiveShift => false;
  @override
  Future<void> checkActiveSession() async {}
  @override
  Future<void> endShift({required double actualClosingCash, required User user, required bool performDayEnd}) async {}
  @override
  Future<ShiftSummaryStats> getCurrentShiftStats() => throw UnimplementedError();
  @override
  Future<int> getNextShiftNumber() async => 1;
  @override
  Future<void> recordCashMovement({required bool isPaidIn, required double amount, required String reason, required String cashierName}) async {}
  @override
  Future<void> setNextShiftNumber(int nextShiftNumber) async {}
  @override
  Future<({BusinessDay day, Shift shift})> startDayAndShift({required double openingBalance, required User user, int? customShiftNumber}) =>
      throw UnimplementedError();
  @override
  Future<Shift> startShift({required double openingBalance, required User user, int? customShiftNumber}) =>
      throw UnimplementedError();
}

void main() {
  const cashier = User(
    id: 1,
    username: 'cashier1',
    displayName: 'Cashier 01',
    pin: '0000',
    role: 'CASHIER',
    active: true,
  );
  const supervisor = User(
    id: 2,
    username: 'sup',
    displayName: 'Supervisor Sam',
    pin: '2222',
    role: 'ADMIN',
    active: true,
  );

  late _InMemorySyncLogRepository syncLogRepo;
  late AuthenticationServiceImpl authService;
  late PosController posController;

  setUp(() {
    syncLogRepo = _InMemorySyncLogRepository();
    authService = AuthenticationServiceImpl(
      _FakeUserRepository([cashier, supervisor]),
      syncLogRepo,
    );
    posController = PosController(
      salesRepository: _FakeSalesRepository(),
      productRepository: _FakeProductRepository(),
      customerRepository: _FakeCustomerRepository(),
      authService: authService,
      syncLogRepository: syncLogRepo,
    );
  });

  group('Audit logging for Login, Logout & POS Actions', () {
    test('stores login success, login failure, and logout details', () async {
      await expectLater(
        authService.loginWithPin('9999'),
        throwsA(isA<AuthenticationException>()),
      );
      await authService.loginWithPin('0000');
      authService.logout(reason: 'More Menu Logout');

      // Allow fire-and-forget logout log microtask to complete
      await Future<void>.delayed(Duration.zero);

      final logs = syncLogRepo.allLogs;
      expect(logs.length, 3);
      expect(logs[0].actionType, 'USER_AUTH');
      expect(logs[0].title, 'Cashier Login Failed');
      expect(logs[0].status, 'FAILED');

      expect(logs[1].actionType, 'USER_AUTH');
      expect(logs[1].title, 'Cashier Login');
      expect(logs[1].details, contains('Cashier 01 (cashier1)'));
      expect(logs[1].status, 'SUCCESS');

      expect(logs[2].actionType, 'USER_AUTH');
      expect(logs[2].title, 'Cashier Logout');
      expect(logs[2].details, contains('Cashier 01 (cashier1)'));
      expect(logs[2].details, contains('More Menu Logout'));
      expect(logs[2].status, 'SUCCESS');
    });

    test('stores POS actions across cart, discount, customer, hold, recall, void & checkout', () async {
      await authService.loginWithPin('0000');

      const prod = Product(
        id: 10,
        code: 'P10',
        barcode: '12345',
        description: 'Coffee & Tea <Special>',
        price: 500.0,
        cost: 300.0,
      );
      posController.addProductToCart(prod, 2);
      posController.updateQuantity(0, 3);
      posController.updateItemDiscount(0, 50);
      posController.setDiscount(100, overrideCashier: supervisor);
      posController.selectCustomer(const Customer(id: 5, name: 'Kasun Perera', phone: '0771234567'));
      final held = await posController.holdCurrentBill(printReceipt: false);
      await posController.resumeHeldBill(held);
      await posController.processPayment(paidAmount: 2000, paymentMethod: 'Cash');

      posController.addCustomItem(description: 'Custom Snack', price: 200);
      posController.clearCart(logVoid: true, overrideCashier: supervisor, reason: 'Bill Voided');

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final titles = syncLogRepo.allLogs.map((l) => l.title).toList();
      expect(titles, contains('Cashier Login'));
      expect(titles, contains('Item Added to Cart'));
      expect(titles, contains('Item Quantity Updated'));
      expect(titles, contains('Item Discount Applied'));
      expect(titles, contains('Bill Discount Applied'));
      expect(titles, contains('Customer Assigned to Bill'));
      expect(titles, contains('Bill Held: ${held.invoiceNo}'));
      expect(titles, contains('Held Bill Recalled: ${held.invoiceNo}'));
      expect(titles.any((t) => t.startsWith('Sale Completed:')), isTrue);
      expect(titles, contains('Custom Item Added to Cart'));
      expect(titles, contains('Bill Voided'));
    });
  });

  group('Excel (.xlsx) log workbook generation & export', () {
    test('builds valid 3-sheet OpenXML .xlsx workbook with escaped text & all records (>100)', () async {
      // Seed 120 mixed logs (including XML special chars) to confirm no 100-row limit
      for (var i = 1; i <= 120; i++) {
        await syncLogRepo.logAction(
          actionType: i % 3 == 0 ? 'USER_AUTH' : 'POS_ACTION',
          title: i % 3 == 0 ? 'Cashier Login #$i' : 'Sale & Item <#$i>',
          details: 'User: Cashier "01" & Co',
          status: i % 5 == 0 ? 'FAILED' : 'SUCCESS',
        );
      }

      final tempDir = Directory.systemTemp.createTempSync('pos_excel_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final result = await LogExcelExportService.exportLogsToExcel(
        syncLogRepo,
        overrideOutputDir: tempDir,
      );

      expect(syncLogRepo.lastRequestedLimit, isNull);
      expect(result.totalLogs, 120);
      expect(result.authLogsCount, 40);
      expect(result.posLogsCount, 80);
      expect(result.fileName, endsWith('.xlsx'));
      expect(File(result.filePath!).existsSync(), isTrue);

      final decodedZip = ZipDecoder().decodeBytes(result.bytes);
      final fileNames = decodedZip.files.map((f) => f.name).toSet();
      expect(fileNames, containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/sheet2.xml',
        'xl/worksheets/sheet3.xml',
      ]));

      final sheet1Xml = utf8.decode(
        decodedZip.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml').content as List<int>,
      );
      final sheet2Xml = utf8.decode(
        decodedZip.files.firstWhere((f) => f.name == 'xl/worksheets/sheet2.xml').content as List<int>,
      );

      expect(sheet1Xml, contains('Sale &amp; Item &lt;#1&gt;'));
      expect(sheet1Xml, contains('Cashier Login #120'));
      expect(sheet2Xml, contains('Cashier Login #120'));
      expect(sheet2Xml, isNot(contains('Sale &amp; Item')));
    });

    testWidgets('Master Management Access has Download Activity Logs (Excel) option and exports .xlsx', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final tempDir = Directory.systemTemp.createTempSync('pos_master_excel_test_');
      LogExcelExportService.debugOverrideOutputDir = tempDir;
      addTearDown(() {
        LogExcelExportService.debugOverrideOutputDir = null;
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      // Stub Android/feedback channels cleanly
      const feedbackChannel = MethodChannel('com.onimta.mobile_pos/feedback');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        feedbackChannel,
        (_) async => true,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(feedbackChannel, null);
      });

      await authService.loginWithPin('0000');
      authService.logout(reason: 'Test');

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            controller: LoginController(authService),
            shiftService: _FakeShiftService(),
            syncLogRepository: syncLogRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Master Management Access via Settings gear icon + password 'onimta1+'
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'onimta1+');
      await tester.tap(find.text('UNLOCK'));
      await tester.pumpAndSettle();

      expect(find.text('Master Management Access'), findsOneWidget);
      expect(find.text('Download Activity Logs (Excel)'), findsOneWidget);

      await tester.tap(find.text('Download Activity Logs (Excel)'));
      await tester.pumpAndSettle();

      expect(find.text('EXCEL LOG EXPORTED'), findsOneWidget);
      expect(find.textContaining('ONIMTA_POS_Logs_'), findsNWidgets(2));
      expect(tempDir.listSync().where((f) => f.path.endsWith('.xlsx')).length, 1);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final titles = syncLogRepo.allLogs.map((l) => l.title).toList();
      expect(titles, contains('Master Management Access Unlocked'));
      expect(titles, contains('Activity Logs Exported to Excel'));
    });
  });
}
