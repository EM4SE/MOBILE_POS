import '../../app/constants/database_constants.dart';

/// Represents an individual item / line in a POS sale transaction
class SaleItem {
  final int? id;
  final int? saleId;
  final int? productId;
  final String productCode;
  final String productDescription;
  final double quantity;
  final double unitPrice;
  final double unitCost;
  final double discount;
  final double lineTotal;

  const SaleItem({
    this.id,
    this.saleId,
    this.productId,
    this.productCode = '',
    required this.productDescription,
    required this.quantity,
    required this.unitPrice,
    this.unitCost = 0.0,
    this.discount = 0.0,
    required this.lineTotal,
  });

  SaleItem copyWith({
    int? id,
    int? saleId,
    int? productId,
    String? productCode,
    String? productDescription,
    double? quantity,
    double? unitPrice,
    double? unitCost,
    double? discount,
    double? lineTotal,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productDescription: productDescription ?? this.productDescription,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      discount: discount ?? this.discount,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colSaleId: saleId,
      DatabaseConstants.colProductId: productId,
      DatabaseConstants.colProductCode: productCode,
      DatabaseConstants.colProductDescription: productDescription,
      DatabaseConstants.colQuantity: quantity,
      DatabaseConstants.colUnitPrice: unitPrice,
      DatabaseConstants.colUnitCost: unitCost,
      'discount': discount,
      DatabaseConstants.colLineTotal: lineTotal,
    };
    if (id != null) {
      map[DatabaseConstants.colId] = id;
    }
    return map;
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map[DatabaseConstants.colId] as int?,
      saleId: map[DatabaseConstants.colSaleId] as int?,
      productId: map[DatabaseConstants.colProductId] as int?,
      productCode: (map[DatabaseConstants.colProductCode] as String?) ?? '',
      productDescription: (map[DatabaseConstants.colProductDescription] as String?) ?? '',
      quantity: ((map[DatabaseConstants.colQuantity] as num?) ?? 1.0).toDouble(),
      unitPrice: ((map[DatabaseConstants.colUnitPrice] as num?) ?? 0.0).toDouble(),
      unitCost: ((map[DatabaseConstants.colUnitCost] as num?) ?? 0.0).toDouble(),
      discount: ((map['discount'] as num?) ?? 0.0).toDouble(),
      lineTotal: ((map[DatabaseConstants.colLineTotal] as num?) ?? 0.0).toDouble(),
    );
  }
}
