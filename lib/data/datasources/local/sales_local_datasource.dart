import '../../../app/constants/database_constants.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/payment_helper.dart';
import '../../models/reports_model.dart';
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
  Future<String> generateNextInvoiceNumber({String prefix = 'INV-'});
  Future<double> getTodayTotalSales();
  Future<List<ItemWiseSaleReportItem>> getItemWiseSalesReport({String? dateFilter});
  Future<TotalSalesReportData> getTotalSalesReport({String? dateFilter});
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
  Future<String> generateNextInvoiceNumber({String prefix = 'INV-'}) async {
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final searchPattern = '$prefix$datePrefix%';
    
    final results = await _databaseService.rawQuery(
      'SELECT ${DatabaseConstants.colInvoiceNo} FROM ${DatabaseConstants.tableSales} WHERE ${DatabaseConstants.colInvoiceNo} LIKE ?',
      [searchPattern],
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
    String candidate = '$prefix$datePrefix-${nextSeq.toString().padLeft(4, '0')}';

    while (true) {
      final exists = await _databaseService.query(
        DatabaseConstants.tableSales,
        where: '${DatabaseConstants.colInvoiceNo} = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (exists.isEmpty) break;
      nextSeq++;
      candidate = '$prefix$datePrefix-${nextSeq.toString().padLeft(4, '0')}';
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

  @override
  Future<List<ItemWiseSaleReportItem>> getItemWiseSalesReport({String? dateFilter}) async {
    String whereClause = 's.${DatabaseConstants.colStatus} = "COMPLETED"';
    List<Object?> args = [];

    if (dateFilter != null && dateFilter.isNotEmpty) {
      whereClause += ' AND s.${DatabaseConstants.colCreatedAt} LIKE ?';
      args.add('$dateFilter%');
    }

    final results = await _databaseService.rawQuery('''
      SELECT si.${DatabaseConstants.colProductDescription} as product_description,
             SUM(si.${DatabaseConstants.colQuantity}) as total_qty,
             SUM(si.${DatabaseConstants.colLineTotal}) as total_amount
      FROM ${DatabaseConstants.tableSaleItems} si
      JOIN ${DatabaseConstants.tableSales} s ON si.${DatabaseConstants.colSaleId} = s.${DatabaseConstants.colId}
      WHERE $whereClause
      GROUP BY si.${DatabaseConstants.colProductDescription}
      ORDER BY total_amount DESC
    ''', args);

    return results.map(ItemWiseSaleReportItem.fromMap).toList();
  }

  @override
  Future<TotalSalesReportData> getTotalSalesReport({String? dateFilter}) async {
    String completedWhere = '${DatabaseConstants.colStatus} = ?';
    String returnWhere = '${DatabaseConstants.colStatus} = ?';
    List<Object?> completedArgs = ['COMPLETED'];
    List<Object?> returnArgs = ['RETURNED'];

    if (dateFilter != null && dateFilter.isNotEmpty) {
      completedWhere += ' AND ${DatabaseConstants.colCreatedAt} LIKE ?';
      completedArgs.add('$dateFilter%');
      returnWhere += ' AND ${DatabaseConstants.colCreatedAt} LIKE ?';
      returnArgs.add('$dateFilter%');
    }

    final completedSales = await _databaseService.query(
      DatabaseConstants.tableSales,
      where: completedWhere,
      whereArgs: completedArgs,
    );

    final returnedSales = await _databaseService.query(
      DatabaseConstants.tableSales,
      where: returnWhere,
      whereArgs: returnArgs,
    );

    int totalInvoices = completedSales.length;
    double grossSales = 0.0;
    double totalDiscount = 0.0;
    double totalTax = 0.0;
    double netSales = 0.0;
    double cashSales = 0.0;
    double cardSales = 0.0;
    double qrSales = 0.0;
    double creditSales = 0.0;

    for (final s in completedSales) {
      final subtotal = ((s[DatabaseConstants.colSubtotal] as num?) ?? 0.0).toDouble();
      final discount = ((s[DatabaseConstants.colDiscount] as num?) ?? 0.0).toDouble();
      final tax = ((s[DatabaseConstants.colTax] as num?) ?? 0.0).toDouble();
      final grandTotal = ((s[DatabaseConstants.colGrandTotal] as num?) ?? 0.0).toDouble();
      final paid = ((s[DatabaseConstants.colPaidAmount] as num?) ?? 0.0).toDouble();
      final rawMethod = s[DatabaseConstants.colPaymentMethod] as String?;

      grossSales += subtotal;
      totalDiscount += discount;
      totalTax += tax;
      netSales += grandTotal;

      final parsedItems = PaymentBreakdownHelper.parse(rawMethod, paid);
      final agg = PaymentBreakdownHelper.aggregate(parsedItems);

      cashSales += agg.cash;
      cardSales += agg.card;
      qrSales += agg.qr;
      creditSales += agg.credit;
    }

    int totalReturnsCount = returnedSales.length;
    double totalReturnsAmount = 0.0;
    for (final r in returnedSales) {
      totalReturnsAmount += ((r[DatabaseConstants.colGrandTotal] as num?) ?? 0.0).toDouble();
    }

    final totalNetRevenue = netSales - totalReturnsAmount;

    return TotalSalesReportData(
      totalInvoices: totalInvoices,
      grossSales: grossSales,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      netSales: netSales,
      totalReturnsCount: totalReturnsCount,
      totalReturnsAmount: totalReturnsAmount,
      totalNetRevenue: totalNetRevenue,
      cashSales: cashSales,
      cardSales: cardSales,
      qrSales: qrSales,
      creditSales: creditSales,
    );
  }
}
