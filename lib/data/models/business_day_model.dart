import '../../app/constants/database_constants.dart';

/// Represents a business operating day
class BusinessDay {
  final int? id;
  final int dayNumber;
  final String openedAt;
  final String? closedAt;
  final String openedBy;
  final String? closedBy;
  final double openingBalance;
  final double closingBalance;
  final double expectedBalance;
  final double totalSales;
  final String status; // 'OPEN', 'CLOSED'

  const BusinessDay({
    this.id,
    required this.dayNumber,
    required this.openedAt,
    this.closedAt,
    required this.openedBy,
    this.closedBy,
    required this.openingBalance,
    this.closingBalance = 0.0,
    this.expectedBalance = 0.0,
    this.totalSales = 0.0,
    this.status = 'OPEN',
  });

  bool get isOpen => status == 'OPEN';

  BusinessDay copyWith({
    int? id,
    int? dayNumber,
    String? openedAt,
    String? closedAt,
    String? openedBy,
    String? closedBy,
    double? openingBalance,
    double? closingBalance,
    double? expectedBalance,
    double? totalSales,
    String? status,
  }) {
    return BusinessDay(
      id: id ?? this.id,
      dayNumber: dayNumber ?? this.dayNumber,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openedBy: openedBy ?? this.openedBy,
      closedBy: closedBy ?? this.closedBy,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      expectedBalance: expectedBalance ?? this.expectedBalance,
      totalSales: totalSales ?? this.totalSales,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colDayNumber: dayNumber,
      DatabaseConstants.colOpenedAt: openedAt,
      DatabaseConstants.colClosedAt: closedAt,
      DatabaseConstants.colOpenedBy: openedBy,
      DatabaseConstants.colClosedBy: closedBy,
      DatabaseConstants.colOpeningBalance: openingBalance,
      DatabaseConstants.colClosingBalance: closingBalance,
      DatabaseConstants.colExpectedBalance: expectedBalance,
      DatabaseConstants.colTotalSales: totalSales,
      DatabaseConstants.colStatus: status,
    };
    if (id != null) {
      map[DatabaseConstants.colId] = id;
    }
    return map;
  }

  factory BusinessDay.fromMap(Map<String, dynamic> map) {
    return BusinessDay(
      id: map[DatabaseConstants.colId] as int?,
      dayNumber: (map[DatabaseConstants.colDayNumber] as num?)?.toInt() ?? 1,
      openedAt: (map[DatabaseConstants.colOpenedAt] as String?) ?? '',
      closedAt: map[DatabaseConstants.colClosedAt] as String?,
      openedBy: (map[DatabaseConstants.colOpenedBy] as String?) ?? '',
      closedBy: map[DatabaseConstants.colClosedBy] as String?,
      openingBalance: ((map[DatabaseConstants.colOpeningBalance] as num?) ?? 0.0).toDouble(),
      closingBalance: ((map[DatabaseConstants.colClosingBalance] as num?) ?? 0.0).toDouble(),
      expectedBalance: ((map[DatabaseConstants.colExpectedBalance] as num?) ?? 0.0).toDouble(),
      totalSales: ((map[DatabaseConstants.colTotalSales] as num?) ?? 0.0).toDouble(),
      status: (map[DatabaseConstants.colStatus] as String?) ?? 'OPEN',
    );
  }
}
