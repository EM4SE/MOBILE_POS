import '../../app/constants/database_constants.dart';

/// Represents an individual cashier shift within a business operating day
class Shift {
  final int? id;
  final int dayId;
  final int shiftNumber;
  final String openedAt;
  final String? closedAt;
  final String cashierUsername;
  final String cashierName;
  final double openingBalance;
  final double closingBalance;
  final double expectedBalance;
  final double cashSales;
  final double totalSales;
  final double paidIn;
  final double paidOut;
  final double cashDifference;
  final String status; // 'OPEN', 'CLOSED'

  const Shift({
    this.id,
    required this.dayId,
    required this.shiftNumber,
    required this.openedAt,
    this.closedAt,
    required this.cashierUsername,
    required this.cashierName,
    required this.openingBalance,
    this.closingBalance = 0.0,
    this.expectedBalance = 0.0,
    this.cashSales = 0.0,
    this.totalSales = 0.0,
    this.paidIn = 0.0,
    this.paidOut = 0.0,
    this.cashDifference = 0.0,
    this.status = 'OPEN',
  });

  bool get isOpen => status == 'OPEN';

  Shift copyWith({
    int? id,
    int? dayId,
    int? shiftNumber,
    String? openedAt,
    String? closedAt,
    String? cashierUsername,
    String? cashierName,
    double? openingBalance,
    double? closingBalance,
    double? expectedBalance,
    double? cashSales,
    double? totalSales,
    double? paidIn,
    double? paidOut,
    double? cashDifference,
    String? status,
  }) {
    return Shift(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      shiftNumber: shiftNumber ?? this.shiftNumber,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      cashierUsername: cashierUsername ?? this.cashierUsername,
      cashierName: cashierName ?? this.cashierName,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      expectedBalance: expectedBalance ?? this.expectedBalance,
      cashSales: cashSales ?? this.cashSales,
      totalSales: totalSales ?? this.totalSales,
      paidIn: paidIn ?? this.paidIn,
      paidOut: paidOut ?? this.paidOut,
      cashDifference: cashDifference ?? this.cashDifference,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      DatabaseConstants.colDayId: dayId,
      DatabaseConstants.colShiftNumber: shiftNumber,
      DatabaseConstants.colOpenedAt: openedAt,
      DatabaseConstants.colClosedAt: closedAt,
      DatabaseConstants.colCashierUsername: cashierUsername,
      DatabaseConstants.colCashierName: cashierName,
      DatabaseConstants.colOpeningBalance: openingBalance,
      DatabaseConstants.colClosingBalance: closingBalance,
      DatabaseConstants.colExpectedBalance: expectedBalance,
      DatabaseConstants.colCashSales: cashSales,
      DatabaseConstants.colTotalSales: totalSales,
      DatabaseConstants.colPaidIn: paidIn,
      DatabaseConstants.colPaidOut: paidOut,
      DatabaseConstants.colCashDifference: cashDifference,
      DatabaseConstants.colStatus: status,
    };
    if (id != null) {
      map[DatabaseConstants.colId] = id;
    }
    return map;
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map[DatabaseConstants.colId] as int?,
      dayId: (map[DatabaseConstants.colDayId] as num?)?.toInt() ?? 0,
      shiftNumber: (map[DatabaseConstants.colShiftNumber] as num?)?.toInt() ?? 1,
      openedAt: (map[DatabaseConstants.colOpenedAt] as String?) ?? '',
      closedAt: map[DatabaseConstants.colClosedAt] as String?,
      cashierUsername: (map[DatabaseConstants.colCashierUsername] as String?) ?? '',
      cashierName: (map[DatabaseConstants.colCashierName] as String?) ?? '',
      openingBalance: ((map[DatabaseConstants.colOpeningBalance] as num?) ?? 0.0).toDouble(),
      closingBalance: ((map[DatabaseConstants.colClosingBalance] as num?) ?? 0.0).toDouble(),
      expectedBalance: ((map[DatabaseConstants.colExpectedBalance] as num?) ?? 0.0).toDouble(),
      cashSales: ((map[DatabaseConstants.colCashSales] as num?) ?? 0.0).toDouble(),
      totalSales: ((map[DatabaseConstants.colTotalSales] as num?) ?? 0.0).toDouble(),
      paidIn: ((map[DatabaseConstants.colPaidIn] as num?) ?? 0.0).toDouble(),
      paidOut: ((map[DatabaseConstants.colPaidOut] as num?) ?? 0.0).toDouble(),
      cashDifference: ((map[DatabaseConstants.colCashDifference] as num?) ?? 0.0).toDouble(),
      status: (map[DatabaseConstants.colStatus] as String?) ?? 'OPEN',
    );
  }
}
