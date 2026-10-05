import '../../app/constants/database_constants.dart';

/// User entity model for POS authentication and role-based access
class User {
  final int? id;
  final String username;
  final String displayName;
  final String pin;
  final String role; // 'ADMIN', 'CASHIER', 'MANAGER'
  final bool active;
  final String? createdAt;

  const User({
    this.id,
    required this.username,
    required this.displayName,
    required this.pin,
    this.role = 'CASHIER',
    this.active = true,
    this.createdAt,
  });

  User copyWith({
    int? id,
    String? username,
    String? displayName,
    String? pin,
    String? role,
    bool? active,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colUsername: username,
      DatabaseConstants.colDisplayName: displayName,
      DatabaseConstants.colPin: pin,
      DatabaseConstants.colRole: role,
      DatabaseConstants.colActive: active ? 1 : 0,
      DatabaseConstants.colCreatedAt: createdAt ?? DateTime.now().toIso8601String(),
    };
    if (id != null) {
      map[DatabaseConstants.colId] = id;
    }
    return map;
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map[DatabaseConstants.colId] as int?,
      username: (map[DatabaseConstants.colUsername] as String?) ?? '',
      displayName: (map[DatabaseConstants.colDisplayName] as String?) ?? '',
      pin: (map[DatabaseConstants.colPin] as String?) ?? '',
      role: (map[DatabaseConstants.colRole] as String?) ?? 'CASHIER',
      active: (map[DatabaseConstants.colActive] as int?) == 1,
      createdAt: map[DatabaseConstants.colCreatedAt] as String?,
    );
  }

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
}
