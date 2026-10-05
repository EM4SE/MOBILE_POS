import '../../app/constants/database_constants.dart';

/// Customer entity model for CRM, POS billing, and tabs/credit
class Customer {
  final int? id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String? createdAt;
  final String? updatedAt;

  const Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.createdAt,
    this.updatedAt,
  });

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? createdAt,
    String? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colName: name,
      DatabaseConstants.colPhone: phone,
      DatabaseConstants.colEmail: email,
      DatabaseConstants.colAddress: address,
      DatabaseConstants.colCreatedAt: createdAt ?? DateTime.now().toIso8601String(),
      DatabaseConstants.colUpdatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    };
    if (id != null) {
      map[DatabaseConstants.colId] = id;
    }
    return map;
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map[DatabaseConstants.colId] as int?,
      name: (map[DatabaseConstants.colName] as String?) ?? '',
      phone: (map[DatabaseConstants.colPhone] as String?) ?? '',
      email: (map[DatabaseConstants.colEmail] as String?) ?? '',
      address: (map[DatabaseConstants.colAddress] as String?) ?? '',
      createdAt: map[DatabaseConstants.colCreatedAt] as String?,
      updatedAt: map[DatabaseConstants.colUpdatedAt] as String?,
    );
  }
}
