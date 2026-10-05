import '../../app/constants/database_constants.dart';

/// Product entity model representing inventory and POS sale items
class Product {
  final int? id;
  final String code;
  final String barcode;
  final String description;
  final double price;
  final double cost;
  final bool active;
  final String? createdAt;
  final String? updatedAt;

  const Product({
    this.id,
    required this.code,
    this.barcode = '',
    required this.description,
    required this.price,
    this.cost = 0.0,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  Product copyWith({
    int? id,
    String? code,
    String? barcode,
    String? description,
    double? price,
    double? cost,
    bool? active,
    String? createdAt,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colCode: code,
      DatabaseConstants.colBarcode: barcode,
      DatabaseConstants.colDescription: description,
      DatabaseConstants.colPrice: price,
      DatabaseConstants.colCost: cost,
      DatabaseConstants.colActive: active ? 1 : 0,
      DatabaseConstants.colCreatedAt: createdAt ?? DateTime.now().toIso8601String(),
      DatabaseConstants.colUpdatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    };
    if (id != null) {
      map[DatabaseConstants.colId] = id;
    }
    return map;
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map[DatabaseConstants.colId] as int?,
      code: (map[DatabaseConstants.colCode] as String?) ?? '',
      barcode: (map[DatabaseConstants.colBarcode] as String?) ?? '',
      description: (map[DatabaseConstants.colDescription] as String?) ?? '',
      price: ((map[DatabaseConstants.colPrice] as num?) ?? 0.0).toDouble(),
      cost: ((map[DatabaseConstants.colCost] as num?) ?? 0.0).toDouble(),
      active: (map[DatabaseConstants.colActive] as int?) == 1,
      createdAt: map[DatabaseConstants.colCreatedAt] as String?,
      updatedAt: map[DatabaseConstants.colUpdatedAt] as String?,
    );
  }
}
