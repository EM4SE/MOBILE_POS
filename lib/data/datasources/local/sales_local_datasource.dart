import '../../../app/constants/database_constants.dart';
import '../../../core/services/database_service.dart';
import '../../models/sale_item_model.dart';
import '../../models/sale_model.dart';

abstract class SalesLocalDataSource {
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

class SalesLocalDataSourceImpl implements SalesLocalDataSource {
  final DatabaseService _databaseService;

  SalesLocalDataSourceImpl(this._databaseService);

  @override
  Future<int> insertSaleWithItems(Sale sale, List<SaleItem> items) async {
    return await _databaseService.transaction<int>((txn) async {
      // 1. Insert header sale record
      final saleMap = sale.toMap();
      final saleId = await txn.insert(
        DatabaseConstants.tableSales,
        saleMap,
      );

      // 2. Insert all line items
      for (final item in items) {
        final itemMap = item.copyWith(saleId: saleId).toMap();
        await txn.insert(
          DatabaseConstants.tableSaleItems,
          itemMap,
        );
      }

      return saleId;
    });
  }

  @override
  Future<Sale?> getSaleById(int id) async {
    final results = await _databaseService.query(
      DatabaseConstants.tableSales,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;

    final items = await getSaleItems(id);
    return Sale.fromMap(results.first, items);
  }

  @override
  Future<Sale?> getSaleByInvoiceNo(String invoiceNo) async {
    final results = await _databaseService.query(
      DatabaseConstants.tableSales,
      where: '${DatabaseConstants.colInvoiceNo} = ?',
      whereArgs: [invoiceNo.trim()],
      limit: 1,
    );
    if (results.isEmpty) return null;

    final saleMap = results.first;
    final saleId = saleMap[DatabaseConstants.colId] as int;
    final items = await getSaleItems(saleId);
    return Sale.fromMap(saleMap, items);
  }

  @override
  Future<List<Sale>> getSales({String? status, int? limit, int? offset}) async {
    String? where;
    List<Object?>? args;

    if (status != null && status.isNotEmpty) {
      where = '${DatabaseConstants.colStatus} = ?';
      args = [status];
    }

    final results = await _databaseService.query(
      DatabaseConstants.tableSales,
      where: where,
      whereArgs: args,
      orderBy: '${DatabaseConstants.colId} DESC',
      limit: limit,
      offset: offset,
    );

    final salesList = <Sale>[];
    for (final map in results) {
      final saleId = map[DatabaseConstants.colId] as int;
      final items = await getSaleItems(saleId);
      salesList.add(Sale.fromMap(map, items));
    }
    return salesList;
  }

  @override
  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final results = await _databaseService.query(
      DatabaseConstants.tableSaleItems,
      where: '${DatabaseConstants.colSaleId} = ?',
      whereArgs: [saleId],
      orderBy: '${DatabaseConstants.colId} ASC',
    );
    return results.map(SaleItem.fromMap).toList();
  }

  @override
  Future<int> updateSaleStatus(int saleId, String status) async {
    return await _databaseService.update(
      DatabaseConstants.tableSales,
      {
        DatabaseConstants.colStatus: status,
        DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [saleId],
    );
  }

  @override
  Future<int> deleteSale(int saleId) async {
    return await _databaseService.transaction<int>((txn) async {
      await txn.delete(
        DatabaseConstants.tableSaleItems,
        where: '${DatabaseConstants.colSaleId} = ?',
        whereArgs: [saleId],
      );
      return await txn.delete(
        DatabaseConstants.tableSales,
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [saleId],
      );
    });
  }

  @override
  Future<String> generateNextInvoiceNumber() async {
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    
    final results = await _databaseService.rawQuery(
      'SELECT ${DatabaseConstants.colInvoiceNo} FROM ${DatabaseConstants.tableSales} WHERE ${DatabaseConstants.colInvoiceNo} LIKE ?',
      ['INV-$datePrefix%'],
    );

    int maxSeq = 0;
    for (final row in results) {
      final inv = row[DatabaseConstants.colInvoiceNo] as String?;
      if (inv != null) {
        final parts = inv.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts.last);
          if (seq != null && seq > maxSeq) {
            maxSeq = seq;
          }
        }
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = 'INV-$datePrefix-${nextSeq.toString().padLeft(4, '0')}';

    while (true) {
      final exists = await _databaseService.query(
        DatabaseConstants.tableSales,
        where: '${DatabaseConstants.colInvoiceNo} = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (exists.isEmpty) break;
      nextSeq++;
      candidate = 'INV-$datePrefix-${nextSeq.toString().padLeft(4, '0')}';
    }

    return candidate;
  }

  @override
  Future<double> getTodayTotalSales() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final result = await _databaseService.rawQuery(
      'SELECT SUM(${DatabaseConstants.colGrandTotal}) as total FROM ${DatabaseConstants.tableSales} WHERE ${DatabaseConstants.colStatus} = "COMPLETED" AND ${DatabaseConstants.colCreatedAt} LIKE ?',
      ['$todayStr%'],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }
}
