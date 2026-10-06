import '../datasources/local/shift_local_datasource.dart';
import '../models/business_day_model.dart';
import '../models/shift_model.dart';

abstract class ShiftRepository {
  Future<BusinessDay?> getActiveDay();
  Future<BusinessDay?> getLatestDay();
  Future<Shift?> getActiveShift();
  Future<Shift?> getLatestShift();
  Future<({BusinessDay day, Shift shift})> startDayAndShift({
    required double openingBalance,
    required String cashierUsername,
    required String cashierName,
  });
  Future<Shift> startShift({
    required BusinessDay day,
    required double openingBalance,
    required String cashierUsername,
    required String cashierName,
  });
  Future<ShiftSummaryStats> getShiftStats(Shift shift);
  Future<ShiftSummaryStats> getDayStats(BusinessDay day);
  Future<void> recordCashMovement({
    required bool isPaidIn,
    required double amount,
    required String reason,
    required String cashierName,
  });
  Future<Shift> closeShift({
    required Shift shift,
    required double actualClosingCash,
  });
  Future<BusinessDay> closeDay({
    required BusinessDay day,
    required double actualClosingCash,
    required String cashierName,
  });
}

class ShiftRepositoryImpl implements ShiftRepository {
  final ShiftLocalDatasource _datasource;

  ShiftRepositoryImpl(this._datasource);

  @override
  Future<BusinessDay?> getActiveDay() => _datasource.getActiveDay();

  @override
  Future<BusinessDay?> getLatestDay() => _datasource.getLatestDay();

  @override
  Future<Shift?> getActiveShift() => _datasource.getActiveShift();

  @override
  Future<Shift?> getLatestShift() => _datasource.getLatestShift();

  @override
  Future<({BusinessDay day, Shift shift})> startDayAndShift({
    required double openingBalance,
    required String cashierUsername,
    required String cashierName,
  }) => _datasource.startDayAndShift(
    openingBalance: openingBalance,
    cashierUsername: cashierUsername,
    cashierName: cashierName,
  );

  @override
  Future<Shift> startShift({
    required BusinessDay day,
    required double openingBalance,
    required String cashierUsername,
    required String cashierName,
  }) => _datasource.startShift(
    day: day,
    openingBalance: openingBalance,
    cashierUsername: cashierUsername,
    cashierName: cashierName,
  );

  @override
  Future<ShiftSummaryStats> getShiftStats(Shift shift) => _datasource.getShiftStats(shift);

  @override
  Future<ShiftSummaryStats> getDayStats(BusinessDay day) => _datasource.getDayStats(day);

  @override
  Future<void> recordCashMovement({
    required bool isPaidIn,
    required double amount,
    required String reason,
    required String cashierName,
  }) => _datasource.recordCashMovement(
    isPaidIn: isPaidIn,
    amount: amount,
    reason: reason,
    cashierName: cashierName,
  );

  @override
  Future<Shift> closeShift({
    required Shift shift,
    required double actualClosingCash,
  }) => _datasource.closeShift(
    shift: shift,
    actualClosingCash: actualClosingCash,
  );

  @override
  Future<BusinessDay> closeDay({
    required BusinessDay day,
    required double actualClosingCash,
    required String cashierName,
  }) => _datasource.closeDay(
    day: day,
    actualClosingCash: actualClosingCash,
    cashierName: cashierName,
  );
}
