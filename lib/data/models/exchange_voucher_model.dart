import '../../app/constants/database_constants.dart';

/// Exchange Voucher Model representing customer merchandise return credit vouchers
class ExchangeVoucher {
  final int? id;
  final String voucherCode;
  final int? customerId;
  final String? customerName;
  final double totalAmount;
  final double remainingAmount;
  final String itemsJson;
  final String status; // 'ACTIVE', 'REDEEMED', 'CANCELLED'
  final String? redeemedInvoiceNo;
  final String cashierName;
  final String createdAt;
  final String? redeemedAt;

  const ExchangeVoucher({
    this.id,
    required this.voucherCode,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    required this.remainingAmount,
    required this.itemsJson,
    this.status = 'ACTIVE',
    this.redeemedInvoiceNo,
    required this.cashierName,
    required this.createdAt,
    this.redeemedAt,
  });

  bool get isActive => status == 'ACTIVE' && remainingAmount > 0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DatabaseConstants.colId: id,
      DatabaseConstants.colVoucherCode: voucherCode,
      DatabaseConstants.colCustomerId: customerId,
      DatabaseConstants.colCustomerName: customerName,
      DatabaseConstants.colTotalAmount: totalAmount,
      DatabaseConstants.colRemainingAmount: remainingAmount,
      DatabaseConstants.colItemsJson: itemsJson,
      DatabaseConstants.colStatus: status,
      DatabaseConstants.colRedeemedInvoiceNo: redeemedInvoiceNo,
      DatabaseConstants.colCashierName: cashierName,
      DatabaseConstants.colCreatedAt: createdAt,
      DatabaseConstants.colRedeemedAt: redeemedAt,
    };
  }

  factory ExchangeVoucher.fromMap(Map<String, dynamic> map) {
    return ExchangeVoucher(
      id: map[DatabaseConstants.colId] as int?,
      voucherCode: map[DatabaseConstants.colVoucherCode] as String? ?? '',
      customerId: map[DatabaseConstants.colCustomerId] as int?,
      customerName: map[DatabaseConstants.colCustomerName] as String?,
      totalAmount: (map[DatabaseConstants.colTotalAmount] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map[DatabaseConstants.colRemainingAmount] as num?)?.toDouble() ?? 0.0,
      itemsJson: map[DatabaseConstants.colItemsJson] as String? ?? '[]',
      status: map[DatabaseConstants.colStatus] as String? ?? 'ACTIVE',
      redeemedInvoiceNo: map[DatabaseConstants.colRedeemedInvoiceNo] as String?,
      cashierName: map[DatabaseConstants.colCashierName] as String? ?? 'Admin',
      createdAt: map[DatabaseConstants.colCreatedAt] as String? ?? DateTime.now().toIso8601String(),
      redeemedAt: map[DatabaseConstants.colRedeemedAt] as String?,
    );
  }

  ExchangeVoucher copyWith({
    int? id,
    String? voucherCode,
    int? customerId,
    String? customerName,
    double? totalAmount,
    double? remainingAmount,
    String? itemsJson,
    String? status,
    String? redeemedInvoiceNo,
    String? cashierName,
    String? createdAt,
    String? redeemedAt,
  }) {
    return ExchangeVoucher(
      id: id ?? this.id,
      voucherCode: voucherCode ?? this.voucherCode,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      itemsJson: itemsJson ?? this.itemsJson,
      status: status ?? this.status,
      redeemedInvoiceNo: redeemedInvoiceNo ?? this.redeemedInvoiceNo,
      cashierName: cashierName ?? this.cashierName,
      createdAt: createdAt ?? this.createdAt,
      redeemedAt: redeemedAt ?? this.redeemedAt,
    );
  }
}
