import '../datasources/local/sales_local_datasource.dart';
import '../models/reports_model.dart';
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
  Future<String> generateNextInvoiceNumber({String prefix = 'INV-'});
  Future<double> getTodayTotalSales();
  Future<List<ItemWiseSaleReportItem>> getItemWiseSalesReport({String? dateFilter});
  Future<TotalSalesReportData> getTotalSalesReport({String? dateFilter});
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
  Future<String> generateNextInvoiceNumber({String prefix = 'INV-'}) {
    return _localDataSource.generateNextInvoiceNumber(prefix: prefix);
  }

  @override
  Future<double> getTodayTotalSales() {
    return _localDataSource.getTodayTotalSales();
  }

  @override
  Future<List<ItemWiseSaleReportItem>> getItemWiseSalesReport({String? dateFilter}) {
    return _localDataSource.getItemWiseSalesReport(dateFilter: dateFilter);
  }

  @override
  Future<TotalSalesReportData> getTotalSalesReport({String? dateFilter}) {
    return _localDataSource.getTotalSalesReport(dateFilter: dateFilter);
  }
}
