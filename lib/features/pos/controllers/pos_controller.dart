import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/utils/feedback_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/exchange_voucher_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_item_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/exchange_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../data/repositories/settings_repository.dart';

/// POS Controller managing billing cart state, calculations, discounts, exchange vouchers, returns, hold bills, and checkout
class PosController extends ChangeNotifier {
  final SalesRepository salesRepository;
  final ProductRepository productRepository;
  final CustomerRepository customerRepository;
  final AuthenticationService authService;
  final SettingsRepository? settingsRepository;
  final ExchangeRepository? exchangeRepository;

  final List<SaleItem> _cartItems = [];
  Customer? _selectedCustomer;
  double _discountAmount = 0.0;
  double? _discountPercentage;
  bool _isDiscountPercentage = false;
  double _taxRate = 0.0; // percentage e.g. 0.0 or 0.08
  int? _editingIndex;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastRecalledBillNo;

  // Active Applied Exchange Voucher Credit for Current Cart
  ExchangeVoucher? _appliedExchangeVoucher;

  // Held Bills in Memory / Session
  final List<Sale> _heldBills = [];

  PosController({
    required this.salesRepository,
    required this.productRepository,
    required this.customerRepository,
    required this.authService,
    this.settingsRepository,
    this.exchangeRepository,
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
      await settingsRepository!.saveSetting('draft_cart_discount_pct', (_discountPercentage ?? 0.0).toString());
      await settingsRepository!.saveSetting('draft_cart_is_pct', _isDiscountPercentage.toString());
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

      final isPctStr = await settingsRepository!.getSetting('draft_cart_is_pct');
      _isDiscountPercentage = isPctStr == 'true';

      final pctStr = await settingsRepository!.getSetting('draft_cart_discount_pct');
      if (pctStr != null && pctStr.isNotEmpty) {
        _discountPercentage = double.tryParse(pctStr);
      }

      final discountStr = await settingsRepository!.getSetting('draft_cart_discount');
      if (discountStr != null && discountStr.isNotEmpty) {
        _discountAmount = double.tryParse(discountStr) ?? 0.0;
      }

      _recalculateDiscounts();
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
  double? get discountPercentage => _discountPercentage;
  bool get isDiscountPercentage => _isDiscountPercentage;
  double get taxRate => _taxRate;
  int? get editingIndex => _editingIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastRecalledBillNo => _lastRecalledBillNo;
  List<Sale> get heldBills => List.unmodifiable(_heldBills);
  ExchangeVoucher? get appliedExchangeVoucher => _appliedExchangeVoucher;

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

  double calculateItemTotal(double quantity, double unitPrice, [double discount = 0.0]) {
    final gross = quantity * unitPrice;
    return (gross - discount).clamp(0.0, double.infinity);
  }

  double get subtotal {
    double sum = 0.0;
    for (final item in _cartItems) {
      sum += item.lineTotal;
    }
    return sum;
  }

  double get exchangeVoucherCredit {
    if (_appliedExchangeVoucher == null) return 0.0;
    final balanceAfterDiscount = (subtotal - _discountAmount).clamp(0.0, double.infinity);
    return _appliedExchangeVoucher!.remainingAmount.clamp(0.0, balanceAfterDiscount);
  }

  double get taxAmount {
    if (_taxRate <= 0) return 0.0;
    final taxable = (subtotal - _discountAmount - exchangeVoucherCredit).clamp(0.0, double.infinity);
    return taxable * _taxRate;
  }

  double get grandTotal {
    final net = subtotal - _discountAmount - exchangeVoucherCredit + taxAmount;
    return net.clamp(0.0, double.infinity);
  }

  void _recalculateDiscounts() {
    final currentSubtotal = subtotal;
    if (_isDiscountPercentage && _discountPercentage != null && _discountPercentage! > 0) {
      _discountAmount = (currentSubtotal * (_discountPercentage! / 100.0)).clamp(0.0, currentSubtotal);
    } else {
      _discountAmount = _discountAmount.clamp(0.0, currentSubtotal);
    }
    if (_cartItems.isEmpty) {
      _discountAmount = 0.0;
      _discountPercentage = null;
      _isDiscountPercentage = false;
    }
  }

  // --- Cart Actions ---

  void addProductToCart(Product product, [double quantity = 1.0]) {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.productId != null && item.productId == product.id,
    );

    if (existingIndex >= 0) {
      final existing = _cartItems[existingIndex];
      final newQty = existing.quantity + quantity;
      final newDiscount = (existing.discount > 0 && existing.quantity > 0)
          ? (existing.discount / existing.quantity) * newQty
          : 0.0;
      _cartItems[existingIndex] = existing.copyWith(
        quantity: newQty,
        discount: newDiscount,
        lineTotal: calculateItemTotal(newQty, existing.unitPrice, newDiscount),
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
          discount: 0.0,
          lineTotal: calculateItemTotal(quantity, product.price, 0.0),
        ),
      );
    }
    _errorMessage = null;
    _recalculateDiscounts();
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
        discount: 0.0,
        lineTotal: calculateItemTotal(quantity, price, 0.0),
      ),
    );
    _errorMessage = null;
    _recalculateDiscounts();
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
    final newDiscount = (item.discount > 0 && item.quantity > 0)
        ? (item.discount / item.quantity) * newQuantity
        : 0.0;

    _cartItems[index] = item.copyWith(
      quantity: newQuantity,
      discount: newDiscount,
      lineTotal: calculateItemTotal(newQuantity, item.unitPrice, newDiscount),
    );
    _recalculateDiscounts();
    saveDraftCart();
    notifyListeners();
  }

  void updatePrice(int index, double newPrice) {
    if (index < 0 || index >= _cartItems.length) return;
    if (newPrice < 0) return;

    final item = _cartItems[index];
    final gross = item.quantity * item.unitPrice;
    final newGross = item.quantity * newPrice;
    final newDiscount = (item.discount > 0 && gross > 0)
        ? ((item.discount / gross) * newGross).clamp(0.0, newGross)
        : 0.0;

    _cartItems[index] = item.copyWith(
      unitPrice: newPrice,
      discount: newDiscount,
      lineTotal: calculateItemTotal(item.quantity, newPrice, newDiscount),
    );
    _recalculateDiscounts();
    saveDraftCart();
    notifyListeners();
  }

  void updateItemDiscount(int index, double discount) {
    if (index < 0 || index >= _cartItems.length) return;
    final item = _cartItems[index];
    final gross = item.quantity * item.unitPrice;
    final validDisc = discount.clamp(0.0, gross);
    _cartItems[index] = item.copyWith(
      discount: validDisc,
      lineTotal: calculateItemTotal(item.quantity, item.unitPrice, validDisc),
    );
    _recalculateDiscounts();
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
      _recalculateDiscounts();
      saveDraftCart();
      notifyListeners();
    }
  }

  void setEditingIndex(int? index) {
    _editingIndex = index;
    notifyListeners();
  }

  void setDiscount(double discount, {bool isPercentage = false, double? percentage}) {
    _isDiscountPercentage = isPercentage;
    _discountPercentage = percentage;
    if (isPercentage && percentage != null && percentage > 0) {
      _discountAmount = (subtotal * (percentage / 100.0)).clamp(0.0, subtotal);
    } else {
      _discountAmount = discount.clamp(0.0, subtotal);
    }
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
    _discountPercentage = null;
    _isDiscountPercentage = false;
    _appliedExchangeVoucher = null;
    _editingIndex = null;
    _errorMessage = null;
    saveDraftCart();
    notifyListeners();
  }

  // --- Exchange Voucher Application ---

  Future<bool> applyExchangeVoucherCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return false;

    if (exchangeRepository == null) {
      throw const PosOperationException('Exchange repository not initialized');
    }

    final voucher = await exchangeRepository!.getVoucherByCode(clean);
    if (voucher == null) {
      throw PosOperationException('No exchange voucher found matching: $clean');
    }

    if (!voucher.isActive) {
      throw PosOperationException(
        'Voucher $clean is already ${voucher.status.toLowerCase()} or has zero balance.',
      );
    }

    _appliedExchangeVoucher = voucher;
    FeedbackHelper.playScanFeedback();
    notifyListeners();
    return true;
  }

  void removeAppliedExchangeVoucher() {
    _appliedExchangeVoucher = null;
    notifyListeners();
  }

  // --- Process Exchange Voucher Issuance ---

  Future<ExchangeVoucher> processExchange() async {
    if (_cartItems.isEmpty) {
      throw const PosOperationException('Cannot create exchange with an empty cart');
    }

    if (exchangeRepository == null) {
      throw const PosOperationException('Exchange repository unavailable');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final voucherCode = await exchangeRepository!.generateNextVoucherCode();
      final exchangeTotal = (subtotal - _discountAmount).clamp(0.0, double.infinity);
      final cashier = authService.currentUser.value?.displayName ?? 'Admin';
      final now = DateTime.now().toIso8601String();

      final itemsPayload = _cartItems.map((i) => {
        'description': i.productDescription,
        'quantity': i.quantity,
        'unitPrice': i.unitPrice,
        'lineTotal': i.lineTotal,
      }).toList();

      final voucher = ExchangeVoucher(
        voucherCode: voucherCode,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
        totalAmount: exchangeTotal,
        remainingAmount: exchangeTotal,
        itemsJson: jsonEncode(itemsPayload),
        status: 'ACTIVE',
        cashierName: cashier,
        createdAt: now,
      );

      await exchangeRepository!.insertVoucher(voucher);

      // Print Exchange Voucher Receipt with Barcode
      await PrinterService.printExchangeReceipt(
        voucherCode: voucherCode,
        totalAmount: exchangeTotal,
        customerName: _selectedCustomer?.name,
        cashierName: cashier,
        items: itemsPayload,
      );

      clearCart();
      _isLoading = false;
      notifyListeners();

      return voucher;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to issue exchange voucher: $e';
      notifyListeners();
      rethrow;
    }
  }

  // --- Process Return / Refund ---

  Future<Sale> processReturn({
    required String paymentMethod,
    String? reason,
  }) async {
    if (_cartItems.isEmpty) {
      throw const PosOperationException('Cannot return an empty cart');
    }

    if (paymentMethod.trim().toLowerCase() == 'credit') {
      throw const PosOperationException('Return refund cannot be processed via Credit.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final returnInvoiceNo = await salesRepository.generateNextInvoiceNumber(prefix: 'RET-');
      final returnTotal = (subtotal - _discountAmount).clamp(0.0, double.infinity);
      final cashier = authService.currentUser.value?.displayName ?? 'Admin';
      final now = DateTime.now().toIso8601String();

      final returnSale = Sale(
        invoiceNo: returnInvoiceNo,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
        subtotal: subtotal,
        discount: _discountAmount,
        tax: taxAmount,
        grandTotal: returnTotal,
        paidAmount: returnTotal,
        changeAmount: 0.0,
        paymentMethod: paymentMethod,
        status: 'RETURNED',
        cashierName: cashier,
        createdAt: now,
      );

      final saleId = await salesRepository.insertSaleWithItems(returnSale, _cartItems);
      final completedReturn = returnSale.copyWith(id: saleId, items: List.from(_cartItems));

      final itemsPayload = _cartItems.map((i) => {
        'description': i.productDescription,
        'quantity': i.quantity,
        'unitPrice': i.unitPrice,
        'lineTotal': i.lineTotal,
      }).toList();

      // Print Return Receipt
      await PrinterService.printReturnReceipt(
        returnNo: returnInvoiceNo,
        refundAmount: returnTotal,
        paymentMethod: paymentMethod,
        reason: reason ?? 'Customer Return',
        customerName: _selectedCustomer?.name,
        cashierName: cashier,
        items: itemsPayload,
      );

      clearCart();
      _isLoading = false;
      notifyListeners();

      return completedReturn;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to process return: $e';
      notifyListeners();
      rethrow;
    }
  }

  // --- Hold and Resume Bills ---

  Future<Sale> holdCurrentBill({bool printReceipt = true}) async {
    if (_cartItems.isEmpty) {
      throw const PosOperationException('Cannot hold an empty bill');
    }

    final invoiceNo = await salesRepository.generateNextInvoiceNumber();
    final cashierName = authService.currentUser.value?.displayName ?? 'Admin';
    final customerName = _selectedCustomer?.name ?? 'Walk-in Customer';

    final heldSale = Sale(
      invoiceNo: invoiceNo,
      customerId: _selectedCustomer?.id,
      customerName: customerName,
      subtotal: subtotal,
      discount: _discountAmount,
      tax: taxAmount,
      grandTotal: grandTotal,
      status: 'HELD',
      cashierName: cashierName,
      items: List.from(_cartItems),
    );

    final totalAmount = grandTotal;
    final totalLines = _cartItems.length;
    final totalQty = _cartItems.fold<double>(0.0, (acc, item) => acc + item.quantity);

    final saleId = await salesRepository.insertSaleWithItems(heldSale, _cartItems);
    final savedHeldSale = heldSale.copyWith(id: saleId);

    _heldBills.insert(0, savedHeldSale);
    clearCart();

    if (printReceipt) {
      try {
        await PrinterService.printHoldReceipt(
          holdNo: invoiceNo,
          totalAmount: totalAmount,
          totalItemsCount: totalLines,
          totalQuantity: totalQty,
          customerName: customerName,
          cashierName: cashierName,
        );
      } catch (e) {
        debugPrint('Hold receipt print failed: $e');
      }
    }

    notifyListeners();
    return savedHeldSale;
  }

  Future<void> resumeHeldBill(Sale heldSale) async {
    _cartItems.clear();
    _cartItems.addAll(heldSale.items);
    _discountAmount = heldSale.discount;
    _selectedCustomer = heldSale.customerId != null
        ? Customer(id: heldSale.customerId, name: heldSale.customerName)
        : null;
    _lastRecalledBillNo = heldSale.invoiceNo;
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

      // Finalize applied exchange voucher if present
      if (_appliedExchangeVoucher != null && exchangeRepository != null) {
        final creditToRedeem = exchangeVoucherCredit;
        await exchangeRepository!.redeemVoucher(
          _appliedExchangeVoucher!.voucherCode,
          invoiceNo,
          creditToRedeem,
        );
      }

      final sale = Sale(
        invoiceNo: invoiceNo,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
        subtotal: subtotal,
        discount: _discountAmount + exchangeVoucherCredit,
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

  // Quick search product by code/barcode to add directly, or apply Exchange Voucher barcode, or recall Held Bill barcode
  Future<bool> quickAddByCodeOrBarcode(String query) async {
    if (query.trim().isEmpty) return false;
    final clean = query.trim();

    // 1. Check if query matches a Held Bill Barcode / Invoice Number
    Sale? matchingHeldBill;
    try {
      matchingHeldBill = _heldBills.where((b) => b.invoiceNo.trim().toUpperCase() == clean.toUpperCase()).firstOrNull;
      if (matchingHeldBill == null) {
        final heldFromDb = await salesRepository.getSales(status: 'HELD');
        matchingHeldBill = heldFromDb.where((b) => b.invoiceNo.trim().toUpperCase() == clean.toUpperCase()).firstOrNull;
      }
    } catch (_) {}

    if (matchingHeldBill != null) {
      if (_cartItems.isNotEmpty) {
        throw PosOperationException(
          'Cannot recall held bill (${matchingHeldBill.invoiceNo}): Current cart is not empty. Please clear or complete current cart first.',
        );
      }
      await resumeHeldBill(matchingHeldBill);
      return true;
    }

    // 2. Check if it's an Exchange Voucher barcode (e.g. EXC-123456 or existing voucher)
    if (clean.toUpperCase().startsWith('EXC-') || clean.toUpperCase().startsWith('EXC')) {
      try {
        final applied = await applyExchangeVoucherCode(clean);
        if (applied) return true;
      } catch (_) {}
    }

    // 3. Product Barcode / Code search
    final product = await productRepository.getProductByBarcode(clean) ??
        await productRepository.getProductByCode(clean);

    if (product != null) {
      addProductToCart(product);
      return true;
    }

    // 4. Fallback: try voucher lookup in case code doesn't start with EXC
    if (exchangeRepository != null) {
      try {
        final applied = await applyExchangeVoucherCode(clean);
        if (applied) return true;
      } catch (_) {}
    }

    return false;
  }
}
