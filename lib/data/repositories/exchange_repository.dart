import '../datasources/local/exchange_local_datasource.dart';
import '../models/exchange_voucher_model.dart';

abstract class ExchangeRepository {
  Future<int> insertVoucher(ExchangeVoucher voucher);
  Future<ExchangeVoucher?> getVoucherByCode(String voucherCode);
  Future<List<ExchangeVoucher>> getVouchers({String? status, int? limit});
  Future<int> redeemVoucher(String voucherCode, String redeemedInvoiceNo, double amountRedeemed);
  Future<String> generateNextVoucherCode();
}

class ExchangeRepositoryImpl implements ExchangeRepository {
  final ExchangeLocalDataSource _localDataSource;

  ExchangeRepositoryImpl(this._localDataSource);

  @override
  Future<int> insertVoucher(ExchangeVoucher voucher) {
    return _localDataSource.insertVoucher(voucher);
  }

  @override
  Future<ExchangeVoucher?> getVoucherByCode(String voucherCode) {
    return _localDataSource.getVoucherByCode(voucherCode);
  }

  @override
  Future<List<ExchangeVoucher>> getVouchers({String? status, int? limit}) {
    return _localDataSource.getVouchers(status: status, limit: limit);
  }

  @override
  Future<int> redeemVoucher(String voucherCode, String redeemedInvoiceNo, double amountRedeemed) {
    return _localDataSource.redeemVoucher(voucherCode, redeemedInvoiceNo, amountRedeemed);
  }

  @override
  Future<String> generateNextVoucherCode() {
    return _localDataSource.generateNextVoucherCode();
  }
}
