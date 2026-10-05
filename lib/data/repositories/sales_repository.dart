import '../datasources/local/sales_local_datasource.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';

abstract class SalesRepository {
  Future<int> insertSaleWithItems(Sale sale, List<SaleItem> items);
  Future<Sale?> getSaleById(int id);
  Future<Sale?> getSaleByInvoiceNo(String invoiceNo);
  Future<List<Sale>> getSales({String? status, int? limit, int? offset});
  Future<List<SaleItem>> getSaleItems(int saleId);
  Future<int> updateSaleStatus(int saleId, String status);
  Future<int> deleteSale(int saleId);
  Future<String> generateNextInvoiceNumber();
  Future<double> getTodayTotalSales();
}

class SalesRepositoryImpl implements SalesRepository {
  final SalesLocalDataSource _localDataSource;

  SalesRepositoryImpl(this._localDataSource);

  @override
  Future<int> insertSaleWithItems(Sale sale, List<SaleItem> items) {
    return _localDataSource.insertSaleWithItems(sale, items);
  }

  @override
  Future<Sale?> getSaleById(int id) {
    return _localDataSource.getSaleById(id);
  }

  @override
  Future<Sale?> getSaleByInvoiceNo(String invoiceNo) {
    return _localDataSource.getSaleByInvoiceNo(invoiceNo);
  }

  @override
  Future<List<Sale>> getSales({String? status, int? limit, int? offset}) {
    return _localDataSource.getSales(status: status, limit: limit, offset: offset);
  }

  @override
  Future<List<SaleItem>> getSaleItems(int saleId) {
    return _localDataSource.getSaleItems(saleId);
  }

  @override
  Future<int> updateSaleStatus(int saleId, String status) {
    return _localDataSource.updateSaleStatus(saleId, status);
  }

  @override
  Future<int> deleteSale(int saleId) {
    return _localDataSource.deleteSale(saleId);
  }

  @override
  Future<String> generateNextInvoiceNumber() {
    return _localDataSource.generateNextInvoiceNumber();
  }

  @override
  Future<double> getTodayTotalSales() {
    return _localDataSource.getTodayTotalSales();
  }
}
