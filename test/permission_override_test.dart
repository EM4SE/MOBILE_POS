import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/app/routes/app_routes.dart';
import 'package:mobile_pos/core/exceptions/app_exceptions.dart';
import 'package:mobile_pos/core/services/authentication_service.dart';
import 'package:mobile_pos/core/services/cashier_permissions_service.dart';
import 'package:mobile_pos/data/models/customer_model.dart';
import 'package:mobile_pos/data/models/product_model.dart';
import 'package:mobile_pos/data/models/reports_model.dart';
import 'package:mobile_pos/data/models/sale_item_model.dart';
import 'package:mobile_pos/data/models/sale_model.dart';
import 'package:mobile_pos/data/models/sync_activity_log_model.dart';
import 'package:mobile_pos/data/models/user_model.dart';
import 'package:mobile_pos/data/repositories/customer_repository.dart';
import 'package:mobile_pos/data/repositories/product_repository.dart';
import 'package:mobile_pos/data/repositories/sales_repository.dart';
import 'package:mobile_pos/data/repositories/settings_repository.dart';
import 'package:mobile_pos/data/repositories/sync_log_repository.dart';
import 'package:mobile_pos/data/repositories/user_repository.dart';
import 'package:mobile_pos/features/more/screens/more_screen.dart';
import 'package:mobile_pos/features/more/widgets/pin_override_sheet.dart';
import 'package:mobile_pos/features/pos/controllers/pos_controller.dart';
import 'package:mobile_pos/features/pos/screens/cash_movement_screen.dart';
import 'package:mobile_pos/features/settings/controllers/settings_controller.dart';
import 'package:mobile_pos/features/settings/screens/settings_screen.dart';

class _FakeUserRepository implements UserRepository {
  final List<User> users;

  _FakeUserRepository(this.users);

  @override
  Future<User?> authenticateByPin(String pin) async {
    for (final u in users) {
      if (u.pin == pin && u.active) return u;
    }
    return null;
  }

  @override
  Future<List<User>> getUsersByPin(String pin) async {
    return users.where((u) => u.pin == pin).toList();
  }

  @override
  Future<List<User>> getAllUsers() async => List.of(users);

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

class _FakeSettingsRepository implements SettingsRepository {
  final Map<String, String> _store = {};

  @override
  Future<Map<String, String>> getAllSettings() async => Map.of(_store);

  @override
  Future<String?> getSetting(String key) async => _store[key];

  @override
  Future<void> saveSetting(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> saveSettings(Map<String, String> settings) async {
    _store.addAll(settings);
  }

  @override
  Future<void> updateSetting(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> updateSettings(Map<String, String> settings) async {
    _store.addAll(settings);
  }
}

class _FakeSalesRepository implements SalesRepository {
  final List<Sale> savedSales = [];
  int _nextId = 1;

  @override
  Future<int> insertSaleWithItems(Sale sale, List<SaleItem> items) async {
    final id = _nextId++;
    savedSales.add(sale.copyWith(id: id, items: List.of(items)));
    return id;
  }

  @override
  Future<Sale?> getSaleById(int id) async =>
      savedSales.where((s) => s.id == id).firstOrNull;

  @override
  Future<Sale?> getSaleByInvoiceNo(String invoiceNo) async =>
      savedSales.where((s) => s.invoiceNo == invoiceNo).firstOrNull;

  @override
  Future<List<Sale>> getSales({String? status, int? limit, int? offset}) async {
    if (status == null) return List.of(savedSales);
    return savedSales.where((s) => s.status == status).toList();
  }

  @override
  Future<List<SaleItem>> getSaleItems(int saleId) async => [];

  @override
  Future<int> updateSaleStatus(int saleId, String status) async => 1;

  @override
  Future<int> markSaleSynced(int saleId, String syncedAt) async => 1;

  @override
  Future<List<Sale>> getUnsyncedSales() async => [];

  @override
  Future<int> deleteSale(int saleId) async => 1;

  @override
  Future<String> generateNextInvoiceNumber({String prefix = ''}) async =>
      '${prefix}INV-000$_nextId';

  @override
  Future<double> getTodayTotalSales() async => 0.0;

  @override
  Future<List<ItemWiseSaleReportItem>> getItemWiseSalesReport({String? dateFilter}) async => [];

  @override
  Future<TotalSalesReportData> getTotalSalesReport({String? dateFilter}) async {
    throw UnimplementedError();
  }
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
  Future<List<Product>> getProducts({
    String? searchQuery,
    bool onlyActive = true,
    int? limit,
    int? offset,
  }) async =>
      [];

  @override
  Future<int> insertProduct(Product product) async => 1;

  @override
  Future<int> syncProductsFromApi({
    String? baseUrl,
    void Function(int count, String status)? onProgress,
  }) async =>
      0;

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
  Future<List<Customer>> getCustomers({
    String? searchQuery,
    int? limit,
    int? offset,
  }) async =>
      [];

  @override
  Future<int> insertCustomer(Customer customer) async => 1;

  @override
  Future<int> updateCustomer(Customer customer) async => 1;
}

class _FakeSyncLogRepository implements SyncLogRepository {
  final List<SyncActivityLog> logs = [];

  @override
  Future<int> clearAllLogs() async {
    logs.clear();
    return 1;
  }

  @override
  Future<Map<String, int>> getLogStats() async => {'total': logs.length};

  @override
  Future<List<SyncActivityLog>> getLogs({
    String? actionType,
    String? status,
    int? limit,
    int? offset,
  }) async =>
      List.of(logs);

  @override
  Future<int> logAction({
    required String actionType,
    required String title,
    String? details,
    required String status,
    responseBody,
    String? errorMessage,
  }) async {
    logs.add(
      SyncActivityLog(
        id: logs.length + 1,
        actionType: actionType,
        title: title,
        details: details,
        status: status,
        errorMessage: errorMessage,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    return logs.length;
  }
}

void main() {
  const admin = User(
    id: 1,
    username: 'admin',
    displayName: 'Admin Master',
    pin: '1234',
    role: 'ADMIN',
    active: true,
  );
  const restrictedCashier = User(
    id: 2,
    username: 'cashier1',
    displayName: 'Cashier 01',
    pin: '0000',
    role: 'CASHIER',
    active: true,
  );
  const supervisor = User(
    id: 3,
    username: 'supervisor',
    displayName: 'Supervisor Sam',
    pin: '2222',
    role: 'CASHIER',
    active: true,
  );
  const inactiveAdmin = User(
    id: 4,
    username: 'old_admin',
    displayName: 'Old Admin',
    pin: '9999',
    role: 'ADMIN',
    active: false,
  );

  late _FakeSettingsRepository settingsRepo;
  late _FakeUserRepository userRepo;
  late AuthenticationServiceImpl authService;
  late CashierPermissionsService permissionsService;
  late _FakeSalesRepository salesRepo;
  late _FakeSyncLogRepository syncLogRepo;
  late PosController posController;

  setUp(() async {
    settingsRepo = _FakeSettingsRepository();
    userRepo = _FakeUserRepository([admin, restrictedCashier, supervisor, inactiveAdmin]);
    authService = AuthenticationServiceImpl(userRepo);
    permissionsService = CashierPermissionsService(settingsRepo);
    salesRepo = _FakeSalesRepository();
    syncLogRepo = _FakeSyncLogRepository();

    await permissionsService.savePermissionsForCashier('cashier1', {
      for (final f in PosFeature.allFeatures) f.id: false,
    });
    await permissionsService.savePermissionsForCashier('supervisor', {
      for (final f in PosFeature.allFeatures) f.id: true,
    });

    posController = PosController(
      salesRepository: salesRepo,
      productRepository: _FakeProductRepository(),
      customerRepository: _FakeCustomerRepository(),
      authService: authService,
      syncLogRepository: syncLogRepo,
    );

    await authService.loginWithPin('0000'); // Log in as restricted Cashier 01
  });

  group('PIN verification & permission override services', () {
    test('verifyPin validates PIN without changing logged-in currentUser', () async {
      expect(authService.currentUser.value?.username, 'cashier1');

      final verified = await authService.verifyPin('2222');
      expect(verified.username, 'supervisor');
      expect(authService.currentUser.value?.username, 'cashier1');
    });

    test('verifyPin rejects invalid and deactivated PINs without touching session', () async {
      await expectLater(
        authService.verifyPin('7777'),
        throwsA(isA<AuthenticationException>()),
      );
      await expectLater(
        authService.verifyPin('9999'),
        throwsA(
          predicate<AuthenticationException>(
            (e) => e.message.contains('deactivated'),
          ),
        ),
      );
      expect(authService.currentUser.value?.username, 'cashier1');
    });

    test('authorizeFeatureWithPin accepts permitted cashier/admin and rejects unpermitted cashier', () async {
      final bySupervisor = await permissionsService.authorizeFeatureWithPin(
        authService: authService,
        pin: '2222',
        featureId: PosFeature.paidOut,
        featureName: 'PAID OUTS',
      );
      expect(bySupervisor.username, 'supervisor');

      final byAdmin = await permissionsService.authorizeFeatureWithPin(
        authService: authService,
        pin: '1234',
        featureId: PosFeature.settings,
        featureName: 'SETTINGS',
      );
      expect(byAdmin.username, 'admin');

      await expectLater(
        permissionsService.authorizeFeatureWithPin(
          authService: authService,
          pin: '0000',
          featureId: PosFeature.paidOut,
          featureName: 'PAID OUTS',
        ),
        throwsA(
          predicate<AuthenticationException>(
            (e) => e.message.contains('does not have permission'),
          ),
        ),
      );
      expect(authService.currentUser.value?.username, 'cashier1');
    });

    test('PosController.holdCurrentBill attributes bill to overrideCashier when provided', () async {
      posController.addCustomItem(description: 'Coffee', price: 250.0);
      final held = await posController.holdCurrentBill(
        printReceipt: false,
        overrideCashier: supervisor,
      );
      expect(held.cashierName, 'Supervisor Sam');
      expect(authService.currentUser.value?.username, 'cashier1');
    });
  });

  group('MoreScreen Logout tile & one-time PIN numpad override UI', () {
    Future<void> enterPinOnKeypad(WidgetTester tester, String pin) async {
      for (final ch in pin.split('')) {
        await tester.tap(find.text(ch).last);
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.tap(find.text('UNLOCK'));
      await tester.pumpAndSettle();
    }

    Widget buildApp() {
      final settingsController = SettingsController(settingsRepo);
      return MaterialApp(
        initialRoute: AppRoutes.more,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.more:
              return MaterialPageRoute(
                builder: (_) => MoreScreen(
                  authService: authService,
                  posController: posController,
                  permissionsService: permissionsService,
                  syncLogRepository: syncLogRepo,
                ),
              );
            case AppRoutes.cashMovement:
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => CashMovementScreen(
                  isPaidIn: args['isPaidIn'] as bool,
                  authService: authService,
                  authorizedBy: args['authorizedBy'] as User?,
                ),
              );
            case AppRoutes.settings:
              return MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  controller: settingsController,
                  authService: authService,
                  authorizedBy: settings.arguments as User?,
                ),
              );
            case AppRoutes.login:
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Center(child: Text('LOGIN_SCREEN'))),
              );
            default:
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: SizedBox.shrink()),
              );
          }
        },
      );
    }

    testWidgets('LOGOUT tile in MoreScreen grid logs out and navigates to login', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final logoutFinder = find.text('LOGOUT');
      await tester.ensureVisible(logoutFinder);
      await tester.pumpAndSettle();
      expect(logoutFinder, findsOneWidget);

      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      expect(find.text('Logout Session'), findsOneWidget);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(authService.currentUser.value, isNull);
      expect(find.text('LOGIN_SCREEN'), findsOneWidget);
    });

    testWidgets('Restricted tile opens numpad PIN sheet, rejects unpermitted PIN, grants single one-time access with permitted cashier', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tap locked PAID OUTS tile
      await tester.tap(find.text('PAID OUTS'));
      await tester.pumpAndSettle();

      // Numpad sheet is loaded
      expect(find.byType(PinOverrideSheet), findsOneWidget);
      expect(find.text('AUTHORIZATION REQUIRED'), findsOneWidget);

      // Entering restricted cashier's own PIN shows error and keeps sheet open
      await enterPinOnKeypad(tester, '0000');
      expect(find.byType(PinOverrideSheet), findsOneWidget);
      expect(find.text('Cashier 01 does not have permission for PAID OUTS.'), findsOneWidget);

      // Entering permitted supervisor PIN unlocks PAID OUTS once with Supervisor Sam
      await enterPinOnKeypad(tester, '2222');
      expect(find.byType(PinOverrideSheet), findsNothing);
      expect(find.text('PAID OUTS (CASH EXPENSE)'), findsOneWidget);
      expect(find.text('One-Time Access • Authorized by Supervisor Sam'), findsOneWidget);
      expect(authService.currentUser.value?.username, 'cashier1');
      expect(syncLogRepo.logs.length, 2);
      expect(syncLogRepo.logs.first.title, 'Override Denied: PAID OUTS');
      expect(syncLogRepo.logs.first.status, 'FAILED');
      expect(syncLogRepo.logs.last.title, 'One-Time Override: PAID OUTS');
      expect(syncLogRepo.logs.last.details, contains('Authorized by: Supervisor Sam'));

      // Return to MoreScreen -> PAID OUTS must still require PIN again (one-time access only)
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('PAID OUTS'));
      await tester.pumpAndSettle();
      expect(find.byType(PinOverrideSheet), findsOneWidget);
    });

    testWidgets('Admin one-time override on SETTINGS exposes Cashier Management once without staying unlocked', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final settingsFinder = find.text('SETTINGS');
      await tester.ensureVisible(settingsFinder);
      await tester.pumpAndSettle();
      await tester.tap(settingsFinder);
      await tester.pumpAndSettle();

      expect(find.byType(PinOverrideSheet), findsOneWidget);
      await enterPinOnKeypad(tester, '1234');

      expect(find.text('SYSTEM SETTINGS'), findsOneWidget);
      expect(find.text('One-Time Access • Authorized by Admin Master'), findsOneWidget);
      expect(find.text('Cashier Management & Permissions'), findsOneWidget);
      expect(authService.currentUser.value?.username, 'cashier1');

      // Back out of Settings -> tapping SETTINGS again prompts PIN again
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(settingsFinder);
      await tester.pumpAndSettle();
      await tester.tap(settingsFinder);
      await tester.pumpAndSettle();
      expect(find.byType(PinOverrideSheet), findsOneWidget);
    });
  });
}
