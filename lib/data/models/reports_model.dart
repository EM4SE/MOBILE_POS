/// Model representing an item-wise sales report entry
class ItemWiseSaleReportItem {
  final String description;
  final double quantity;
  final double totalAmount;

  const ItemWiseSaleReportItem({
    required this.description,
    required this.quantity,
    required this.totalAmount,
  });

  factory ItemWiseSaleReportItem.fromMap(Map<String, dynamic> map) {
    return ItemWiseSaleReportItem(
      description: (map['product_description'] as String?) ?? 'Item',
      quantity: ((map['total_qty'] as num?) ?? 0.0).toDouble(),
      totalAmount: ((map['total_amount'] as num?) ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'description': description,
    'quantity': quantity,
    'totalAmount': totalAmount,
  };
}

class TotalSalesReportData {
  final int totalInvoices;
  final double grossSales;
  final double totalDiscount;
  final double totalTax;
  final double netSales;
  final int totalReturnsCount;
  final double totalReturnsAmount;
  final double totalNetRevenue;
  final double cashSales;
  final double cardSales;
  final double qrSales;
  final double creditSales;

  const TotalSalesReportData({
    required this.totalInvoices,
    required this.grossSales,
    required this.totalDiscount,
    required this.totalTax,
    required this.netSales,
    required this.totalReturnsCount,
    required this.totalReturnsAmount,
    required this.totalNetRevenue,
    required this.cashSales,
    required this.cardSales,
    required this.qrSales,
    required this.creditSales,
  });
}
