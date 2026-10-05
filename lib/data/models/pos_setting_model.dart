import '../../app/constants/database_constants.dart';

/// Key-value setting model for POS configuration, printer, tax, and store info
class PosSetting {
  final String key;
  final String value;
  final String? updatedAt;

  const PosSetting({
    required this.key,
    required this.value,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colKey: key,
      DatabaseConstants.colValue: value,
      DatabaseConstants.colUpdatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory PosSetting.fromMap(Map<String, dynamic> map) {
    return PosSetting(
      key: (map[DatabaseConstants.colKey] as String?) ?? '',
      value: (map[DatabaseConstants.colValue] as String?) ?? '',
      updatedAt: map[DatabaseConstants.colUpdatedAt] as String?,
    );
  }
}
