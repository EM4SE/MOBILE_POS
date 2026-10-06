import 'dart:math';
import '../../../app/constants/database_constants.dart';
import '../../../core/services/database_service.dart';
import '../../models/exchange_voucher_model.dart';

abstract class ExchangeLocalDataSource {
  Future<int> insertVoucher(ExchangeVoucher voucher);
  Future<ExchangeVoucher?> getVoucherByCode(String voucherCode);
  Future<List<ExchangeVoucher>> getVouchers({String? status, int? limit});
  Future<int> redeemVoucher(String voucherCode, String redeemedInvoiceNo, double amountRedeemed);
  Future<String> generateNextVoucherCode();
}

class ExchangeLocalDataSourceImpl implements ExchangeLocalDataSource {
  final DatabaseService _databaseService;

  ExchangeLocalDataSourceImpl(this._databaseService);

  @override
  Future<int> insertVoucher(ExchangeVoucher voucher) async {
    return await _databaseService.insert(
      DatabaseConstants.tableExchangeVouchers,
      voucher.toMap(),
    );
  }

  @override
  Future<ExchangeVoucher?> getVoucherByCode(String voucherCode) async {
    final clean = voucherCode.trim().toUpperCase();
    final results = await _databaseService.query(
      DatabaseConstants.tableExchangeVouchers,
      where: 'UPPER(${DatabaseConstants.colVoucherCode}) = ?',
      whereArgs: [clean],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ExchangeVoucher.fromMap(results.first);
  }

  @override
  Future<List<ExchangeVoucher>> getVouchers({String? status, int? limit}) async {
    String? where;
    List<Object?>? args;
    if (status != null && status.isNotEmpty) {
      where = '${DatabaseConstants.colStatus} = ?';
      args = [status];
    }
    final results = await _databaseService.query(
      DatabaseConstants.tableExchangeVouchers,
      where: where,
      whereArgs: args,
      orderBy: '${DatabaseConstants.colId} DESC',
      limit: limit,
    );
    return results.map((m) => ExchangeVoucher.fromMap(m)).toList();
  }

  @override
  Future<int> redeemVoucher(String voucherCode, String redeemedInvoiceNo, double amountRedeemed) async {
    final clean = voucherCode.trim().toUpperCase();
    final existing = await getVoucherByCode(clean);
    if (existing == null) return 0;

    final newRemaining = (existing.remainingAmount - amountRedeemed).clamp(0.0, double.infinity);
    final newStatus = newRemaining <= 0.01 ? 'REDEEMED' : 'ACTIVE';

    return await _databaseService.update(
      DatabaseConstants.tableExchangeVouchers,
      {
        DatabaseConstants.colRemainingAmount: newRemaining,
        DatabaseConstants.colStatus: newStatus,
        DatabaseConstants.colRedeemedInvoiceNo: redeemedInvoiceNo,
        DatabaseConstants.colRedeemedAt: DateTime.now().toIso8601String(),
      },
      where: 'UPPER(${DatabaseConstants.colVoucherCode}) = ?',
      whereArgs: [clean],
    );
  }

  @override
  Future<String> generateNextVoucherCode() async {
    // Generates a clean, scannable format e.g. EXC-749281
    final random = Random();
    for (int i = 0; i < 10; i++) {
      final numPart = (100000 + random.nextInt(900000)).toString();
      final code = 'EXC-$numPart';
      final existing = await getVoucherByCode(code);
      if (existing == null) {
        return code;
      }
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return 'EXC-$timestamp';
  }
}
