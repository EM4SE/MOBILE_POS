import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_item_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../data/repositories/settings_repository.dart';

/// POS Controller managing billing cart state, calculations, discounts, hold bills, and checkout
class PosController extends ChangeNotifier {
  final SalesRepository salesRepository;
  final ProductRepository productRepository;
  final CustomerRepository customerRepository;
  final AuthenticationService authService;
  final SettingsRepository? settingsRepository;

  final List<SaleItem> _cartItems = [];
  Customer? _selectedCustomer;
  double _discountAmount = 0.0;
  double _taxRate = 0.0; // percentage e.g. 0.0 or 0.08
  int? _editingIndex;
  bool _isLoading = false;
  String? _errorMessage;

  // Held Bills in Memory / Session
  final List<Sale> _heldBills = [];

  PosController({
    required this.salesRepository,
    required this.productRepository,
    required this.customerRepository,
    required this.authService,
    this.settingsRepository,
  }) {
    loadHeldBills();
    loadDraftCart();
  }

  Future<void> saveDraftCart() async {
    if (settingsRepository == null) return;
    try {
      final itemsJson = jsonEncode(_cartItems.map((i) => i.toMap()).toList());
      final customerJson = _selectedCustomer != null ? jsonEncode(_selectedCustomer!.toMap()) : '';
      await settingsRepository!.saveSetting('draft_cart_items', itemsJson);
      await settingsRepository!.saveSetting('draft_cart_customer', customerJson);
      await settingsRepository!.saveSetting('draft_cart_discount', _discountAmount.toString());
    } catch (e) {
      debugPrint('Error saving draft cart: $e');
    }
  }

  Future<void> loadDraftCart() async {
    if (settingsRepository == null) return;
    try {
      final itemsJson = await settingsRepository!.getSetting('draft_cart_items');
      if (itemsJson != null && itemsJson.isNotEmpty) {
        final List decoded = jsonDecode(itemsJson);
        _cartItems.clear();
        for (final itemMap in decoded) {
          _cartItems.add(SaleItem.fromMap(Map<String, dynamic>.from(itemMap)));
        }
      }

      final customerJson = await settingsRepository!.getSetting('draft_cart_customer');
      if (customerJson != null && customerJson.isNotEmpty) {
        _selectedCustomer = Customer.fromMap(jsonDecode(customerJson));
      }

      final discountStr = await settingsRepository!.getSetting('draft_cart_discount');
      if (discountStr != null && discountStr.isNotEmpty) {
        _discountAmount = double.tryParse(discountStr) ?? 0.0;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading draft cart: $e');
    }
  }

  Future<void> loadHeldBills() async {
    try {
      final savedHeldBills = await salesRepository.getSales(status: 'HELD');
      _heldBills.clear();
      _heldBills.addAll(savedHeldBills);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading held bills: $e');
    }
  }

  Future<List<Customer>> searchCustomers(String query) {
    return customerRepository.getCustomers(searchQuery: query);
  }

  List<SaleItem> get cartItems => List.unmodifiable(_cartItems);
  Customer? get selectedCustomer => _selectedCustomer;
  double get discountAmount => _discountAmount;
  double get taxRate => _taxRate;
  int? get editingIndex => _editingIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Sale> get heldBills => List.unmodifiable(_heldBills);

  int get totalItemCount {
    int count = 0;
    for (final item in _cartItems) {
      count += item.quantity.toInt();
    }
    return count;
  }

  int get uniqueItemCount => _cartItems.length;

  bool get isCartEmpty => _cartItems.isEmpty;

  // --- Calculations ---

  double calculateItemTotal(double quantity, double unitPrice) {
    return quantity * unitPrice;
  }

  double get subtotal {
    double sum = 0.0;
    for (final item in _cartItems) {
      sum += item.lineTotal;
    }
    return sum;
  }

  double get taxAmount {
    if (_taxRate <= 0) return 0.0;
    final taxable = (subtotal - _discountAmount).clamp(0.0, double.infinity);
    return taxable * _taxRate;
  }

  double get grandTotal {
    final net = subtotal - _discountAmount + taxAmount;
    return net.clamp(0.0, double.infinity);
  }

  // --- Cart Actions ---

  void addProductToCart(Product product, [double quantity = 1.0]) {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.productId != null && item.productId == product.id,
    );

    if (existingIndex >= 0) {
      final existing = _cartItems[existingIndex];
      final newQty = existing.quantity + quantity;
      _cartItems[existingIndex] = existing.copyWith(
        quantity: newQty,
        lineTotal: calculateItemTotal(newQty, existing.unitPrice),
      );
    } else {
      _cartItems.add(
        SaleItem(
          productId: product.id,
          productCode: product.code,
          productDescription: product.description,
          quantity: quantity,
          unitPrice: product.price,
          unitCost: product.cost,
          lineTotal: calculateItemTotal(quantity, product.price),
        ),
      );
    }
    _errorMessage = null;
    saveDraftCart();
    notifyListeners();
  }

  void addCustomItem({
    required String description,
    required double price,
    double quantity = 1.0,
    String code = 'CUSTOM',
  }) {
    if (description.trim().isEmpty) {
      _errorMessage = 'Item description is required';
      notifyListeners();
      return;
    }
    if (price < 0 || quantity <= 0) {
      _errorMessage = 'Price and Quantity must be positive';
      notifyListeners();
      return;
    }

    _cartItems.add(
      SaleItem(
        productCode: code,
        productDescription: description.trim(),
        quantity: quantity,
        unitPrice: price,
        lineTotal: calculateItemTotal(quantity, price),
      ),
    );
    _errorMessage = null;
    saveDraftCart();
    notifyListeners();
  }

  void updateQuantity(int index, double newQuantity) {
    if (index < 0 || index >= _cartItems.length) return;

    if (newQuantity <= 0) {
      removeItem(index);
      return;
    }

    final item = _cartItems[index];
    _cartItems[index] = item.copyWith(
      quantity: newQuantity,
      lineTotal: calculateItemTotal(newQuantity, item.unitPrice),
    );
    saveDraftCart();
    notifyListeners();
  }

  void updatePrice(int index, double newPrice) {
    if (index < 0 || index >= _cartItems.length) return;
    if (newPrice < 0) return;

    final item = _cartItems[index];
    _cartItems[index] = item.copyWith(
      unitPrice: newPrice,
      lineTotal: calculateItemTotal(item.quantity, newPrice),
    );
    saveDraftCart();
    notifyListeners();
  }

  void updateDescription(int index, String newDescription) {
    if (index < 0 || index >= _cartItems.length) return;
    if (newDescription.trim().isEmpty) return;

    final item = _cartItems[index];
    _cartItems[index] = item.copyWith(
      productDescription: newDescription.trim(),
    );
    saveDraftCart();
    notifyListeners();
  }

  void removeItem(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
      }
      saveDraftCart();
      notifyListeners();
    }
  }

  void setEditingIndex(int? index) {
    _editingIndex = index;
    notifyListeners();
  }

  void setDiscount(double discount) {
    _discountAmount = discount.clamp(0.0, subtotal);
    saveDraftCart();
    notifyListeners();
  }

  void setTaxRate(double rate) {
    _taxRate = rate.clamp(0.0, 1.0);
    saveDraftCart();
    notifyListeners();
  }

  void selectCustomer(Customer? customer) {
    _selectedCustomer = customer;
    saveDraftCart();
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _selectedCustomer = null;
    _discountAmount = 0.0;
    _editingIndex = null;
    _errorMessage = null;
    saveDraftCart();
    notifyListeners();
  }

  // --- Hold and Resume Bills ---

  Future<void> holdCurrentBill() async {
    if (_cartItems.isEmpty) {
      throw const PosOperationException('Cannot hold an empty bill');
    }

    final invoiceNo = await salesRepository.generateNextInvoiceNumber();
    final heldSale = Sale(
      invoiceNo: invoiceNo,
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      subtotal: subtotal,
      discount: _discountAmount,
      tax: taxAmount,
      grandTotal: grandTotal,
      status: 'HELD',
      cashierName: authService.currentUser.value?.displayName ?? 'Admin',
      items: List.from(_cartItems),
    );

    final saleId = await salesRepository.insertSaleWithItems(heldSale, _cartItems);
    final savedHeldSale = heldSale.copyWith(id: saleId);

    _heldBills.insert(0, savedHeldSale);
    clearCart();
  }

  Future<void> resumeHeldBill(Sale heldSale) async {
    _cartItems.clear();
    _cartItems.addAll(heldSale.items);
    _discountAmount = heldSale.discount;
    _selectedCustomer = heldSale.customerId != null
        ? Customer(id: heldSale.customerId, name: heldSale.customerName)
        : null;
    _heldBills.removeWhere((b) => b.id == heldSale.id || b.invoiceNo == heldSale.invoiceNo);

    if (heldSale.id != null) {
      await salesRepository.deleteSale(heldSale.id!);
    }
    notifyListeners();
  }

  Future<void> deleteHeldBill(Sale heldSale) async {
    _heldBills.removeWhere((b) => b.id == heldSale.id || b.invoiceNo == heldSale.invoiceNo);
    if (heldSale.id != null) {
      await salesRepository.deleteSale(heldSale.id!);
    }
    notifyListeners();
  }

  // --- Checkout / Payment Completion ---

  Future<Sale> processPayment({
    required double paidAmount,
    required String paymentMethod,
  }) async {
    if (_cartItems.isEmpty) {
      throw const PosOperationException('Cannot checkout an empty cart');
    }

    if (paidAmount < grandTotal && paymentMethod == 'Cash') {
      throw const PosOperationException('Paid amount is less than total amount');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final invoiceNo = await salesRepository.generateNextInvoiceNumber();
      final change = (paidAmount - grandTotal).clamp(0.0, double.infinity);

      final sale = Sale(
        invoiceNo: invoiceNo,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
        subtotal: subtotal,
        discount: _discountAmount,
        tax: taxAmount,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        changeAmount: change,
        paymentMethod: paymentMethod,
        status: 'COMPLETED',
        cashierName: authService.currentUser.value?.displayName ?? 'Admin',
      );

      final saleId = await salesRepository.insertSaleWithItems(sale, _cartItems);
      final completedSale = sale.copyWith(id: saleId, items: List.from(_cartItems));

      clearCart();
      _isLoading = false;
      notifyListeners();

      return completedSale;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to complete sale: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Quick search product by code/barcode to add directly
  Future<bool> quickAddByCodeOrBarcode(String query) async {
    if (query.trim().isEmpty) return false;
    final clean = query.trim();

    final product = await productRepository.getProductByBarcode(clean) ??
        await productRepository.getProductByCode(clean);

    if (product != null) {
      addProductToCart(product);
      return true;
    }
    return false;
  }
}
