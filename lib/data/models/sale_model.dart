import '../../app/constants/database_constants.dart';
import 'sale_item_model.dart';

/// Represents a finalized or held POS sales transaction/bill
class Sale {
  final int? id;
  final String invoiceNo;
  final int? customerId;
  final String customerName;
  final double subtotal;
  final double discount;
  final double tax;
  final double grandTotal;
  final double paidAmount;
  final double changeAmount;
  final String paymentMethod;
  final String status; // 'COMPLETED', 'HELD', 'CANCELLED'
  final String cashierName;
  final String? createdAt;
  final String? updatedAt;
  final List<SaleItem> items;

  const Sale({
    this.id,
    required this.invoiceNo,
    this.customerId,
    this.customerName = 'Walk-in Customer',
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.grandTotal,
    this.paidAmount = 0.0,
    this.changeAmount = 0.0,
    this.paymentMethod = 'Cash',
    this.status = 'COMPLETED',
    this.cashierName = 'Admin',
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  Sale copyWith({
    int? id,
    String? invoiceNo,
    int? customerId,
    String? customerName,
    double? subtotal,
    double? discount,
    double? tax,
    double? grandTotal,
    double? paidAmount,
    double? changeAmount,
    String? paymentMethod,
    String? status,
    String? cashierName,
    String? createdAt,
    String? updatedAt,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      cashierName: cashierName ?? this.cashierName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colInvoiceNo: invoiceNo,
      DatabaseConstants.colCustomerId: customerId,
      DatabaseConstants.colCustomerName: customerName,
      DatabaseConstants.colSubtotal: subtotal,
      DatabaseConstants.colDiscount: discount,
      DatabaseConstants.colTax: tax,
      DatabaseConstants.colGrandTotal: grandTotal,
      DatabaseConstants.colPaidAmount: paidAmount,
      DatabaseConstants.colChangeAmount: changeAmount,
      DatabaseConstants.colPaymentMethod: paymentMethod,
      DatabaseConstants.colStatus: status,
      DatabaseConstants.colCashierName: cashierName,
      DatabaseConstants.colCreatedAt: createdAt ?? DateTime.now().toIso8601String(),
      DatabaseConstants.colUpdatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    };
    if (id != null) {
      map[DatabaseConstants.colId] = id;
    }
    return map;
  }

  factory Sale.fromMap(Map<String, dynamic> map, [List<SaleItem> items = const []]) {
    return Sale(
      id: map[DatabaseConstants.colId] as int?,
      invoiceNo: (map[DatabaseConstants.colInvoiceNo] as String?) ?? '',
      customerId: map[DatabaseConstants.colCustomerId] as int?,
      customerName: (map[DatabaseConstants.colCustomerName] as String?) ?? 'Walk-in Customer',
      subtotal: ((map[DatabaseConstants.colSubtotal] as num?) ?? 0.0).toDouble(),
      discount: ((map[DatabaseConstants.colDiscount] as num?) ?? 0.0).toDouble(),
      tax: ((map[DatabaseConstants.colTax] as num?) ?? 0.0).toDouble(),
      grandTotal: ((map[DatabaseConstants.colGrandTotal] as num?) ?? 0.0).toDouble(),
      paidAmount: ((map[DatabaseConstants.colPaidAmount] as num?) ?? 0.0).toDouble(),
      changeAmount: ((map[DatabaseConstants.colChangeAmount] as num?) ?? 0.0).toDouble(),
      paymentMethod: (map[DatabaseConstants.colPaymentMethod] as String?) ?? 'Cash',
      status: (map[DatabaseConstants.colStatus] as String?) ?? 'COMPLETED',
      cashierName: (map[DatabaseConstants.colCashierName] as String?) ?? 'Admin',
      createdAt: map[DatabaseConstants.colCreatedAt] as String?,
      updatedAt: map[DatabaseConstants.colUpdatedAt] as String?,
      items: items,
    );
  }
}
