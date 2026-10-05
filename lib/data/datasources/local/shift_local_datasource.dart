import '../../../app/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../models/business_day_model.dart';
import '../../models/shift_model.dart';

class ShiftSummaryStats {
  final int totalInvoices;
  final double grossSales;
  final double totalDiscount;
  final double totalTax;
  final double grandTotalSales;
  final double cashSales;
  final double cardSales;
  final double otherSales;
  final double paidIn;
  final double paidOut;
  final double openingBalance;
  final double expectedCash;

  const ShiftSummaryStats({
    required this.totalInvoices,
    required this.grossSales,
    required this.totalDiscount,
    required this.totalTax,
    required this.grandTotalSales,
    required this.cashSales,
    required this.cardSales,
    required this.otherSales,
    required this.paidIn,
    required this.paidOut,
    required this.openingBalance,
    required this.expectedCash,
  });
}

class ShiftLocalDatasource {
  final DatabaseHelper _dbHelper;

  ShiftLocalDatasource([DatabaseHelper? dbHelper]) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Retrieves currently active business day (if any)
  Future<BusinessDay?> getActiveDay() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseConstants.tableBusinessDays,
      where: '${DatabaseConstants.colStatus} = ?',
      whereArgs: ['OPEN'],
      orderBy: '${DatabaseConstants.colId} DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return BusinessDay.fromMap(results.first);
  }

  /// Retrieves currently active shift (if any)
  Future<Shift?> getActiveShift() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseConstants.tableShifts,
      where: '${DatabaseConstants.colStatus} = ?',
      whereArgs: ['OPEN'],
      orderBy: '${DatabaseConstants.colId} DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Shift.fromMap(results.first);
  }

  /// Starts a brand new Business Day and its first Shift atomically
  Future<({BusinessDay day, Shift shift})> startDayAndShift({
    required double openingBalance,
    required String cashierUsername,
    required String cashierName,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      // 1. Calculate next day number
      final dayMaxResult = await txn.rawQuery(
        'SELECT MAX(${DatabaseConstants.colDayNumber}) as max_day FROM ${DatabaseConstants.tableBusinessDays}',
      );
      final int nextDayNum = ((dayMaxResult.first['max_day'] as num?)?.toInt() ?? 0) + 1;

      final dayMap = {
        DatabaseConstants.colDayNumber: nextDayNum,
        DatabaseConstants.colOpenedAt: now,
        DatabaseConstants.colClosedAt: null,
        DatabaseConstants.colOpenedBy: cashierName,
        DatabaseConstants.colClosedBy: null,
        DatabaseConstants.colOpeningBalance: openingBalance,
        DatabaseConstants.colClosingBalance: 0.0,
        DatabaseConstants.colExpectedBalance: openingBalance,
        DatabaseConstants.colTotalSales: 0.0,
        DatabaseConstants.colStatus: 'OPEN',
      };
      final dayId = await txn.insert(DatabaseConstants.tableBusinessDays, dayMap);

      // 2. Create Shift 1 for this new day
      final shiftMap = {
        DatabaseConstants.colDayId: dayId,
        DatabaseConstants.colShiftNumber: 1,
        DatabaseConstants.colOpenedAt: now,
        DatabaseConstants.colClosedAt: null,
        DatabaseConstants.colCashierUsername: cashierUsername,
        DatabaseConstants.colCashierName: cashierName,
        DatabaseConstants.colOpeningBalance: openingBalance,
        DatabaseConstants.colClosingBalance: 0.0,
        DatabaseConstants.colExpectedBalance: openingBalance,
        DatabaseConstants.colCashSales: 0.0,
        DatabaseConstants.colTotalSales: 0.0,
        DatabaseConstants.colPaidIn: 0.0,
        DatabaseConstants.colPaidOut: 0.0,
        DatabaseConstants.colCashDifference: 0.0,
        DatabaseConstants.colStatus: 'OPEN',
      };
      final shiftId = await txn.insert(DatabaseConstants.tableShifts, shiftMap);

      return (
        day: BusinessDay.fromMap({...dayMap, DatabaseConstants.colId: dayId}),
        shift: Shift.fromMap({...shiftMap, DatabaseConstants.colId: shiftId}),
      );
    });
  }

  /// Starts a new Shift under the currently active day
  Future<Shift> startShift({
    required BusinessDay day,
    required double openingBalance,
    required String cashierUsername,
    required String cashierName,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final shiftMaxResult = await db.rawQuery(
      'SELECT MAX(${DatabaseConstants.colShiftNumber}) as max_shift FROM ${DatabaseConstants.tableShifts} WHERE ${DatabaseConstants.colDayId} = ?',
      [day.id],
    );
    final int nextShiftNum = ((shiftMaxResult.first['max_shift'] as num?)?.toInt() ?? 0) + 1;

    final shiftMap = {
      DatabaseConstants.colDayId: day.id,
      DatabaseConstants.colShiftNumber: nextShiftNum,
      DatabaseConstants.colOpenedAt: now,
      DatabaseConstants.colClosedAt: null,
      DatabaseConstants.colCashierUsername: cashierUsername,
      DatabaseConstants.colCashierName: cashierName,
      DatabaseConstants.colOpeningBalance: openingBalance,
      DatabaseConstants.colClosingBalance: 0.0,
      DatabaseConstants.colExpectedBalance: openingBalance,
      DatabaseConstants.colCashSales: 0.0,
      DatabaseConstants.colTotalSales: 0.0,
      DatabaseConstants.colPaidIn: 0.0,
      DatabaseConstants.colPaidOut: 0.0,
      DatabaseConstants.colCashDifference: 0.0,
      DatabaseConstants.colStatus: 'OPEN',
    };
    final shiftId = await db.insert(DatabaseConstants.tableShifts, shiftMap);
    return Shift.fromMap({...shiftMap, DatabaseConstants.colId: shiftId});
  }

  /// Calculates real-time sales, payment breakdown, and expected drawer balance for a shift
  Future<ShiftSummaryStats> getShiftStats(Shift shift) async {
    final db = await _dbHelper.database;
    final openedAt = shift.openedAt;

    final sales = await db.query(
      DatabaseConstants.tableSales,
      where: '${DatabaseConstants.colCreatedAt} >= ? AND ${DatabaseConstants.colStatus} = ?',
      whereArgs: [openedAt, 'COMPLETED'],
    );

    int totalInvoices = sales.length;
    double grossSales = 0.0;
    double totalDiscount = 0.0;
    double totalTax = 0.0;
    double grandTotalSales = 0.0;
    double cashSales = 0.0;
    double cardSales = 0.0;
    double otherSales = 0.0;

    for (final s in sales) {
      final subtotal = ((s[DatabaseConstants.colSubtotal] as num?) ?? 0.0).toDouble();
      final discount = ((s[DatabaseConstants.colDiscount] as num?) ?? 0.0).toDouble();
      final tax = ((s[DatabaseConstants.colTax] as num?) ?? 0.0).toDouble();
      final grandTotal = ((s[DatabaseConstants.colGrandTotal] as num?) ?? 0.0).toDouble();
      final paid = ((s[DatabaseConstants.colPaidAmount] as num?) ?? 0.0).toDouble();
      final paymentMethod = (s[DatabaseConstants.colPaymentMethod] as String?) ?? 'Cash';

      grossSales += subtotal;
      totalDiscount += discount;
      totalTax += tax;
      grandTotalSales += grandTotal;

      if (paymentMethod.toLowerCase().contains('cash')) {
        cashSales += paid;
      } else if (paymentMethod.toLowerCase().contains('card')) {
        cardSales += paid;
      } else {
        otherSales += paid;
      }
    }

    final double expectedCash = shift.openingBalance + cashSales + shift.paidIn - shift.paidOut;

    return ShiftSummaryStats(
      totalInvoices: totalInvoices,
      grossSales: grossSales,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      grandTotalSales: grandTotalSales,
      cashSales: cashSales,
      cardSales: cardSales,
      otherSales: otherSales,
      paidIn: shift.paidIn,
      paidOut: shift.paidOut,
      openingBalance: shift.openingBalance,
      expectedCash: expectedCash,
    );
  }

  /// Closes an active shift with final cash in hand
  Future<Shift> closeShift({
    required Shift shift,
    required double actualClosingCash,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final stats = await getShiftStats(shift);

    final cashDiff = actualClosingCash - stats.expectedCash;

    await db.update(
      DatabaseConstants.tableShifts,
      {
        DatabaseConstants.colClosedAt: now,
        DatabaseConstants.colClosingBalance: actualClosingCash,
        DatabaseConstants.colExpectedBalance: stats.expectedCash,
        DatabaseConstants.colCashSales: stats.cashSales,
        DatabaseConstants.colTotalSales: stats.grandTotalSales,
        DatabaseConstants.colCashDifference: cashDiff,
        DatabaseConstants.colStatus: 'CLOSED',
      },
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [shift.id],
    );

    return shift.copyWith(
      closedAt: now,
      closingBalance: actualClosingCash,
      expectedBalance: stats.expectedCash,
      cashSales: stats.cashSales,
      totalSales: stats.grandTotalSales,
      cashDifference: cashDiff,
      status: 'CLOSED',
    );
  }

  /// Closes an active Business Day
  Future<BusinessDay> closeDay({
    required BusinessDay day,
    required double actualClosingCash,
    required String cashierName,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final daySalesResult = await db.rawQuery('''
      SELECT COUNT(*) as total_count, SUM(${DatabaseConstants.colGrandTotal}) as total_sales
      FROM ${DatabaseConstants.tableSales}
      WHERE ${DatabaseConstants.colCreatedAt} >= ? AND ${DatabaseConstants.colStatus} = 'COMPLETED'
    ''', [day.openedAt]);

    final totalSales = ((daySalesResult.first['total_sales'] as num?) ?? 0.0).toDouble();

    await db.update(
      DatabaseConstants.tableBusinessDays,
      {
        DatabaseConstants.colClosedAt: now,
        DatabaseConstants.colClosedBy: cashierName,
        DatabaseConstants.colClosingBalance: actualClosingCash,
        DatabaseConstants.colTotalSales: totalSales,
        DatabaseConstants.colStatus: 'CLOSED',
      },
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [day.id],
    );

    return day.copyWith(
      closedAt: now,
      closedBy: cashierName,
      closingBalance: actualClosingCash,
      totalSales: totalSales,
      status: 'CLOSED',
    );
  }
}
