import 'package:flutter/foundation.dart';
import '../../data/datasources/local/shift_local_datasource.dart';
import '../../data/datasources/remote/shift_remote_datasource.dart';
import '../../data/models/business_day_model.dart';
import '../../data/models/shift_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/sync_log_repository.dart';
import '../utils/currency_formatter.dart';
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
    int? customShiftNumber,
  });
  Future<Shift> startShift({
    required double openingBalance,
    required User user,
    int? customShiftNumber,
  });
  Future<int> getNextShiftNumber();
  Future<void> setNextShiftNumber(int nextShiftNumber);
  Future<ShiftSummaryStats> getCurrentShiftStats();
  Future<void> recordCashMovement({
    required bool isPaidIn,
    required double amount,
    required String reason,
    required String cashierName,
  });
  Future<void> endShift({
    required double actualClosingCash,
    required User user,
    required bool performDayEnd,
  });
}

class ShiftServiceImpl implements ShiftService {
  final ShiftRepository _repository;
  final ShiftRemoteDataSource? _remoteDataSource;
  final SyncLogRepository? _syncLogRepository;
  final ValueNotifier<BusinessDay?> _activeDay = ValueNotifier<BusinessDay?>(null);
  final ValueNotifier<Shift?> _activeShift = ValueNotifier<Shift?>(null);

  ShiftServiceImpl(
    this._repository, [
    this._remoteDataSource,
    this._syncLogRepository,
  ]);

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
  Future<int> getNextShiftNumber() => _repository.getNextShiftNumber();

  @override
  Future<void> setNextShiftNumber(int nextShiftNumber) => _repository.setNextShiftNumber(nextShiftNumber);

  @override
  Future<({BusinessDay day, Shift shift})> startDayAndShift({
    required double openingBalance,
    required User user,
    int? customShiftNumber,
  }) async {
    final result = await _repository.startDayAndShift(
      openingBalance: openingBalance,
      cashierUsername: user.username,
      cashierName: user.displayName,
      customShiftNumber: customShiftNumber,
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

    await _syncLogRepository?.logAction(
      actionType: 'SHIFT_EVENT',
      title: 'Day & Shift Started',
      details: 'Day #${result.day.dayNumber}, Shift #${result.shift.shiftNumber} | Float: ${CurrencyFormatter.formatWithSymbol(openingBalance)} | Cashier: ${user.displayName}',
      status: 'SUCCESS',
    );

    return result;
  }

  @override
  Future<Shift> startShift({
    required double openingBalance,
    required User user,
    int? customShiftNumber,
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
      customShiftNumber: customShiftNumber,
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

    await _syncLogRepository?.logAction(
      actionType: 'SHIFT_EVENT',
      title: 'Shift Started',
      details: 'Day #${day.dayNumber}, Shift #${shift.shiftNumber} | Float: ${CurrencyFormatter.formatWithSymbol(openingBalance)} | Cashier: ${user.displayName}',
      status: 'SUCCESS',
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
  Future<void> recordCashMovement({
    required bool isPaidIn,
    required double amount,
    required String reason,
    required String cashierName,
  }) async {
    await _repository.recordCashMovement(
      isPaidIn: isPaidIn,
      amount: amount,
      reason: reason,
      cashierName: cashierName,
    );
    await checkActiveSession();
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

    // If Day End is requested, verify with ERP API FIRST
    // If API call fails or returns error, abort so Day End is NOT performed in POS system
    Map<String, dynamic>? dayEndApiRes;
    if (performDayEnd && currentDay != null && _remoteDataSource != null) {
      final dayStartDate = currentDay.openedAt;
      try {
        dayEndApiRes = await _remoteDataSource.sendDayEnd(
          location: '01',
          unit: '01',
          dayStartDate: dayStartDate,
        );
      } catch (e) {
        debugPrint('Day End ERP iid 7 call error: $e');
        await _syncLogRepository?.logAction(
          actionType: 'SHIFT_EVENT',
          title: 'Day End ERP API Failed (Iid 7)',
          details: 'Day End aborted in POS. Business Day #${currentDay.dayNumber} remains open. Server error: $e',
          status: 'FAILED',
          errorMessage: e.toString(),
        );
        // Abort: do NOT perform day end or shift end in POS system
        throw Exception('Day End API failed: $e. Day End was cancelled in POS.');
      }
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
      nonCashSales: stats.nonCashSales,
      nonCashBreakdown: stats.nonCashBreakdown,
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
      final dayStats = await _repository.getDayStats(currentDay);
      final closedDay = await _repository.closeDay(
        day: currentDay,
        actualClosingCash: actualClosingCash,
        cashierName: user.displayName,
      );

      // Log successful sync with ERP API
      if (dayEndApiRes != null) {
        final dayStartDate = closedDay.openedAt.isNotEmpty ? closedDay.openedAt : currentDay.openedAt;
        await _syncLogRepository?.logAction(
          actionType: 'SHIFT_EVENT',
          title: 'Day End ERP API Synced (Iid 7)',
          details: 'Business Day #${closedDay.dayNumber} closed | Location: 01 | Unit: 01 | Start Date: $dayStartDate | Cashier: ${user.displayName} | Actual Cash: ${CurrencyFormatter.formatWithSymbol(actualClosingCash)}',
          status: 'SUCCESS',
          responseBody: dayEndApiRes,
        );
      }

      // Automatic Receipt Print for Day End
      await PrinterService.printShiftEventReceipt(
        title: '*** DAY END FINANCIAL REPORT ***',
        dayNumber: closedDay.dayNumber,
        shiftNumber: closedShift.shiftNumber,
        cashierName: user.displayName,
        isEndReport: true,
        openedAt: closedDay.openedAt,
        openingBalance: closedDay.openingBalance,
        totalInvoices: dayStats.totalInvoices,
        grossSales: dayStats.grossSales,
        discount: dayStats.totalDiscount,
        tax: dayStats.totalTax,
        netSales: closedDay.totalSales,
        cashSales: dayStats.cashSales,
        nonCashSales: dayStats.nonCashSales,
        nonCashBreakdown: dayStats.nonCashBreakdown,
        cardSales: dayStats.cardSales,
        otherSales: dayStats.otherSales,
        paidIn: dayStats.paidIn,
        paidOut: dayStats.paidOut,
        expectedCash: dayStats.expectedCash,
        actualCash: actualClosingCash,
        cashDiff: actualClosingCash - dayStats.expectedCash,
      );

      _activeDay.value = null;
    }
  }
}
