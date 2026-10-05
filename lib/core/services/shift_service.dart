import 'package:flutter/foundation.dart';
import '../../data/datasources/local/shift_local_datasource.dart';
import '../../data/models/business_day_model.dart';
import '../../data/models/shift_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/shift_repository.dart';
import 'printer_service.dart';

abstract class ShiftService {
  ValueListenable<BusinessDay?> get activeDay;
  ValueListenable<Shift?> get activeShift;
  bool get hasActiveDay;
  bool get hasActiveShift;

  Future<void> checkActiveSession();
  Future<({BusinessDay day, Shift shift})> startDayAndShift({
    required double openingBalance,
    required User user,
  });
  Future<Shift> startShift({
    required double openingBalance,
    required User user,
  });
  Future<ShiftSummaryStats> getCurrentShiftStats();
  Future<void> endShift({
    required double actualClosingCash,
    required User user,
    required bool performDayEnd,
  });
}

class ShiftServiceImpl implements ShiftService {
  final ShiftRepository _repository;
  final ValueNotifier<BusinessDay?> _activeDay = ValueNotifier<BusinessDay?>(null);
  final ValueNotifier<Shift?> _activeShift = ValueNotifier<Shift?>(null);

  ShiftServiceImpl(this._repository);

  @override
  ValueListenable<BusinessDay?> get activeDay => _activeDay;

  @override
  ValueListenable<Shift?> get activeShift => _activeShift;

  @override
  bool get hasActiveDay => _activeDay.value != null;

  @override
  bool get hasActiveShift => _activeShift.value != null;

  @override
  Future<void> checkActiveSession() async {
    final day = await _repository.getActiveDay();
    final shift = await _repository.getActiveShift();
    _activeDay.value = day;
    _activeShift.value = shift;
  }

  @override
  Future<({BusinessDay day, Shift shift})> startDayAndShift({
    required double openingBalance,
    required User user,
  }) async {
    final result = await _repository.startDayAndShift(
      openingBalance: openingBalance,
      cashierUsername: user.username,
      cashierName: user.displayName,
    );

    _activeDay.value = result.day;
    _activeShift.value = result.shift;

    // Automatic Receipt Print for Day & Shift Start
    await PrinterService.printShiftEventReceipt(
      title: '*** DAY & SHIFT START ***',
      dayNumber: result.day.dayNumber,
      shiftNumber: result.shift.shiftNumber,
      cashierName: user.displayName,
      isEndReport: false,
      openingBalance: openingBalance,
      openedAt: result.shift.openedAt,
    );

    return result;
  }

  @override
  Future<Shift> startShift({
    required double openingBalance,
    required User user,
  }) async {
    final day = _activeDay.value ?? await _repository.getActiveDay();
    if (day == null) {
      throw StateError('Cannot start shift without an active business day');
    }

    final shift = await _repository.startShift(
      day: day,
      openingBalance: openingBalance,
      cashierUsername: user.username,
      cashierName: user.displayName,
    );

    _activeShift.value = shift;

    // Automatic Receipt Print for Shift Start
    await PrinterService.printShiftEventReceipt(
      title: '*** SHIFT START ***',
      dayNumber: day.dayNumber,
      shiftNumber: shift.shiftNumber,
      cashierName: user.displayName,
      isEndReport: false,
      openingBalance: openingBalance,
      openedAt: shift.openedAt,
    );

    return shift;
  }

  @override
  Future<ShiftSummaryStats> getCurrentShiftStats() async {
    final shift = _activeShift.value;
    if (shift == null) {
      throw StateError('No active shift to retrieve statistics');
    }
    return await _repository.getShiftStats(shift);
  }

  @override
  Future<void> endShift({
    required double actualClosingCash,
    required User user,
    required bool performDayEnd,
  }) async {
    final currentShift = _activeShift.value;
    final currentDay = _activeDay.value;

    if (currentShift == null) {
      throw StateError('No active shift to close');
    }

    final stats = await _repository.getShiftStats(currentShift);
    final closedShift = await _repository.closeShift(
      shift: currentShift,
      actualClosingCash: actualClosingCash,
    );

    // Automatic Receipt Print for Shift End (Z-Report)
    await PrinterService.printShiftEventReceipt(
      title: '*** SHIFT END (Z-REPORT) ***',
      dayNumber: currentDay?.dayNumber ?? 1,
      shiftNumber: closedShift.shiftNumber,
      cashierName: user.displayName,
      isEndReport: true,
      openedAt: closedShift.openedAt,
      openingBalance: closedShift.openingBalance,
      totalInvoices: stats.totalInvoices,
      grossSales: stats.grossSales,
      discount: stats.totalDiscount,
      tax: stats.totalTax,
      netSales: stats.grandTotalSales,
      cashSales: stats.cashSales,
      cardSales: stats.cardSales,
      otherSales: stats.otherSales,
      paidIn: stats.paidIn,
      paidOut: stats.paidOut,
      expectedCash: stats.expectedCash,
      actualCash: actualClosingCash,
      cashDiff: closedShift.cashDifference,
    );

    _activeShift.value = null;

    if (performDayEnd && currentDay != null) {
      final closedDay = await _repository.closeDay(
        day: currentDay,
        actualClosingCash: actualClosingCash,
        cashierName: user.displayName,
      );

      // Automatic Receipt Print for Day End
      await PrinterService.printShiftEventReceipt(
        title: '*** DAY END FINANCIAL REPORT ***',
        dayNumber: closedDay.dayNumber,
        shiftNumber: closedShift.shiftNumber,
        cashierName: user.displayName,
        isEndReport: true,
        openedAt: closedDay.openedAt,
        openingBalance: closedDay.openingBalance,
        totalInvoices: stats.totalInvoices,
        grossSales: stats.grossSales,
        discount: stats.totalDiscount,
        tax: stats.totalTax,
        netSales: closedDay.totalSales,
        cashSales: stats.cashSales,
        cardSales: stats.cardSales,
        otherSales: stats.otherSales,
        paidIn: stats.paidIn,
        paidOut: stats.paidOut,
        expectedCash: stats.expectedCash,
        actualCash: actualClosingCash,
        cashDiff: closedShift.cashDifference,
      );

      _activeDay.value = null;
    }
  }
}
