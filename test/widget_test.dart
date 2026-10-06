import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/services/authentication_service.dart';
import 'package:mobile_pos/data/models/customer_model.dart';
import 'package:mobile_pos/data/models/product_model.dart';
import 'package:mobile_pos/data/models/reports_model.dart';
import 'package:mobile_pos/data/models/sale_item_model.dart';
import 'package:mobile_pos/data/models/sale_model.dart';
import 'package:mobile_pos/data/models/user_model.dart';
import 'package:mobile_pos/data/repositories/customer_repository.dart';
import 'package:mobile_pos/data/repositories/product_repository.dart';
import 'package:mobile_pos/data/repositories/sales_repository.dart';
import 'package:mobile_pos/data/repositories/user_repository.dart';
import 'package:mobile_pos/features/authentication/controllers/login_controller.dart';
import 'package:mobile_pos/features/pos/controllers/pos_controller.dart';

// Mock implementations for unit testing
class FakeUserRepository implements UserRepository {
  @override
  Future<User?> authenticateByPin(String pin) async {
    if (pin == '1234') {
      return const User(id: 1, username: 'admin', displayName: 'Admin', pin: '1234', role: 'ADMIN');
    }
    return null;
  }

  @override
  Future<List<User>> getAllUsers() async => [];
  @override
  Future<User?> getUserById(int id) async => null;
  @override
  Future<int> insertUser(User user) async => 1;
  @override
  Future<int> updateUser(User user) async => 1;
  @override
  Future<int> deleteUser(int id) async => 1;
}

class FakeProductRepository implements ProductRepository {
  @override
  Future<List<Product>> getProducts({String? searchQuery, bool onlyActive = true, int? limit, int? offset}) async => [];
  @override
  Future<Product?> getProductById(int id) async => null;
  @override
  Future<Product?> getProductByCode(String code) async => null;
  @override
  Future<Product?> getProductByBarcode(String barcode) async => null;
  @override
  Future<int> insertProduct(Product product) async => 1;
  @override
  Future<int> updateProduct(Product product) async => 1;
  @override
  Future<int> deleteProduct(int id) async => 1;
  @override
  Future<int> countProducts({String? searchQuery, bool onlyActive = true}) async => 0;
}

class FakeCustomerRepository implements CustomerRepository {
  @override
  Future<List<Customer>> getCustomers({String? searchQuery, int? limit, int? offset}) async => [];
  @override
  Future<Customer?> getCustomerById(int id) async => null;
  @override
  Future<int> insertCustomer(Customer customer) async => 1;
  @override
  Future<int> updateCustomer(Customer customer) async => 1;
  @override
  Future<int> deleteCustomer(int id) async => 1;
  @override
  Future<int> countCustomers({String? searchQuery}) async => 0;
}

class FakeSalesRepository implements SalesRepository {
  @override
  Future<int> insertSaleWithItems(Sale sale, List<SaleItem> items) async => 1;
  @override
  Future<Sale?> getSaleById(int id) async => null;
  @override
  Future<Sale?> getSaleByInvoiceNo(String invoiceNo) async => null;
  @override
  Future<List<Sale>> getSales({String? status, int? limit, int? offset}) async => [];
  @override
  Future<List<SaleItem>> getSaleItems(int saleId) async => [];
  @override
  Future<int> updateSaleStatus(int saleId, String status) async => 1;
  @override
  Future<int> deleteSale(int saleId) async => 1;
  @override
  Future<String> generateNextInvoiceNumber({String prefix = 'INV-'}) async => '${prefix}20261004-0001';
  @override
  Future<double> getTodayTotalSales() async => 0.0;
  @override
  Future<List<ItemWiseSaleReportItem>> getItemWiseSalesReport({String? dateFilter}) async => [];
  @override
  Future<TotalSalesReportData> getTotalSalesReport({String? dateFilter}) async => const TotalSalesReportData(
    totalInvoices: 0,
    grossSales: 0.0,
    totalDiscount: 0.0,
    totalTax: 0.0,
    netSales: 0.0,
    totalReturnsCount: 0,
    totalReturnsAmount: 0.0,
    totalNetRevenue: 0.0,
    cashSales: 0.0,
    cardSales: 0.0,
    qrSales: 0.0,
    creditSales: 0.0,
  );
}

void main() {
  group('POS Controller & Calculation Tests', () {
    late PosController posController;
    late AuthenticationService authService;

    setUp(() {
      final userRepo = FakeUserRepository();
      authService = AuthenticationServiceImpl(userRepo);
      posController = PosController(
        salesRepository: FakeSalesRepository(),
        productRepository: FakeProductRepository(),
        customerRepository: FakeCustomerRepository(),
        authService: authService,
      );
    });

    test('Add item to cart and calculate totals correctly', () {
      const p1 = Product(id: 1, code: 'P101', description: 'Coca Cola', price: 250.0);
      const p2 = Product(id: 2, code: 'P102', description: 'Lunch Buffet', price: 850.0);

      posController.addProductToCart(p1, 2);
      expect(posController.cartItems.length, 1);
      expect(posController.cartItems.first.lineTotal, 500.0);
      expect(posController.subtotal, 500.0);

      posController.addProductToCart(p2, 1);
      expect(posController.cartItems.length, 2);
      expect(posController.totalItemCount, 3);
      expect(posController.subtotal, 1350.0);
      expect(posController.grandTotal, 1350.0);
    });

    test('Quantity update and price recalculation', () {
      const p1 = Product(id: 1, code: 'P101', description: 'Coca Cola', price: 250.0);
      posController.addProductToCart(p1, 1);

      posController.updateQuantity(0, 3);
      expect(posController.cartItems.first.quantity, 3);
      expect(posController.cartItems.first.lineTotal, 750.0);
      expect(posController.grandTotal, 750.0);

      posController.updatePrice(0, 300.0);
      expect(posController.cartItems.first.unitPrice, 300.0);
      expect(posController.cartItems.first.lineTotal, 900.0);
      expect(posController.grandTotal, 900.0);
    });

    test('Apply discount to cart', () {
      const p1 = Product(id: 1, code: 'P101', description: 'Coca Cola', price: 500.0);
      posController.addProductToCart(p1, 2); // 1000.0 total

      posController.setDiscount(100.0);
      expect(posController.discountAmount, 100.0);
      expect(posController.grandTotal, 900.0);
    });
  });

  group('Authentication & LoginController Tests', () {
    late LoginController loginController;
    late AuthenticationService authService;

    setUp(() {
      final userRepo = FakeUserRepository();
      authService = AuthenticationServiceImpl(userRepo);
      loginController = LoginController(authService);
    });

    test('Keypad append digit and backspace', () {
      loginController.appendDigit('1');
      loginController.appendDigit('2');
      loginController.appendDigit('3');
      expect(loginController.pin, '123');

      loginController.backspace();
      expect(loginController.pin, '12');

      loginController.clearPin();
      expect(loginController.pin, '');
    });

    test('Login with valid PIN', () async {
      loginController.appendDigit('1');
      loginController.appendDigit('2');
      loginController.appendDigit('3');
      loginController.appendDigit('4');

      final user = await loginController.login();
      expect(user, isNotNull);
      expect(user?.displayName, 'Admin');
      expect(authService.isAuthenticated, isTrue);
    });

    test('Login with invalid PIN sets error message', () async {
      loginController.appendDigit('9');
      loginController.appendDigit('9');
      loginController.appendDigit('9');
      loginController.appendDigit('9');

      final user = await loginController.login();
      expect(user, isNull);
      expect(loginController.errorMessage, isNotNull);
      expect(authService.isAuthenticated, isFalse);
    });
  });
}
