import '../../../core/utils/payment_helper.dart';
import '../datasources/remote/bill_sync_remote_datasource.dart';
import '../models/sale_model.dart';
import 'sales_repository.dart';
import 'sync_log_repository.dart';

abstract class BillSyncRepository {
  Map<String, dynamic> buildBillPayload(
    Sale sale, {
    String? locationCode,
    String? unitCode,
    String? userName,
    String? customerCode,
    String? customerPhone,
    String? salesman,
    bool? isDiscountPercentage,
  });

  Future<Map<String, dynamic>> syncSale(
    Sale sale, {
    String? userName,
    String? customerCode,
    String? customerPhone,
    String? salesman,
    String? baseUrl,
    bool? isDiscountPercentage,
  });

  Future<Map<String, dynamic>> syncPendingSales({String? baseUrl});
}

class BillSyncRepositoryImpl implements BillSyncRepository {
  final BillSyncRemoteDataSource _remoteDataSource;
  final SalesRepository _salesRepository;
  final SyncLogRepository _syncLogRepository;

  BillSyncRepositoryImpl({
    required BillSyncRemoteDataSource remoteDataSource,
    required SalesRepository salesRepository,
    required SyncLogRepository syncLogRepository,
  })  : _remoteDataSource = remoteDataSource,
        _salesRepository = salesRepository,
        _syncLogRepository = syncLogRepository;

  @override
  Map<String, dynamic> buildBillPayload(
    Sale sale, {
    String? locationCode,
    String? unitCode,
    String? userName,
    String? customerCode,
    String? customerPhone,
    String? salesman,
    bool? isDiscountPercentage,
  }) {
    // 1. Build line items array
    final transDt = sale.items.map((item) {
      final discPer = (item.unitPrice > 0 && item.quantity > 0 && item.discount > 0)
          ? ((item.discount / (item.unitPrice * item.quantity)) * 100)
          : 0.0;

      return {
        'prod_Code': item.productCode.isNotEmpty ? item.productCode : (item.productId?.toString() ?? ''),
        'prod_Name': item.productDescription,
        'qty': item.quantity,
        'purchase_Price': item.unitCost > 0 ? item.unitCost : item.unitPrice,
        'selling_Price': item.unitPrice,
        'discount': item.discount,
        'discPer': double.parse(discPer.toStringAsFixed(2)),
        'amount': item.lineTotal,
      };
    }).toList();

    // 2. Build payment lines array
    final transPay = <Map<String, dynamic>>[];
    int payId = 1;

    final bool hasDiscount = sale.discount > 0;
    final bool isPercentage = isDiscountPercentage ?? sale.isDiscountPercentage;

    if (hasDiscount) {
      // 1. Initial SUB TOTAL before discount
      transPay.add({
        'id': payId++,
        'PayMode': 'SUB TOTAL',
        'payMode': 'SUB TOTAL',
        'cardType': 'SUB TOTAL',
        'cardRef': '',
        'amount': sale.subtotal,
      });

      // 2. DISCOUNT line with hardcoded cardType
      transPay.add({
        'id': payId++,
        'PayMode': 'DISCOUNT',
        'payMode': 'DISCOUNT',
        'cardType': isPercentage ? 'MANUAL DISCOUNT %' : 'MANUAL DISCOUNT AMT',
        'cardRef': '',
        'amount': sale.discount,
      });

      // 3. SUB TOTAL after discount
      transPay.add({
        'id': payId++,
        'PayMode': 'SUB TOTAL',
        'payMode': 'SUB TOTAL',
        'cardType': 'SUB TOTAL',
        'cardRef': '',
        'amount': sale.grandTotal,
      });
    } else {
      // Initial SUB TOTAL without discount
      transPay.add({
        'id': payId++,
        'PayMode': 'SUB TOTAL',
        'payMode': 'SUB TOTAL',
        'cardType': 'SUB TOTAL',
        'cardRef': '',
        'amount': sale.grandTotal,
      });
    }

    final breakdown = PaymentBreakdownHelper.parse(sale.paymentMethod, sale.paidAmount);

    if (breakdown.isNotEmpty) {
      for (final item in breakdown) {
        final mode = item.method.toUpperCase();
        transPay.add({
          'id': payId++,
          'PayMode': mode,
          'payMode': mode,
          'cardType': mode,
          'cardRef': item.cardRef ?? '',
          'amount': item.amount,
        });
      }
    } else {
      final singleMode = (sale.paymentMethod.isNotEmpty ? sale.paymentMethod : 'CASH').toUpperCase();
      transPay.add({
        'id': payId++,
        'PayMode': singleMode,
        'payMode': singleMode,
        'cardType': singleMode,
        'cardRef': '',
        'amount': sale.paidAmount > 0 ? sale.paidAmount : sale.grandTotal,
      });
    }

    // If change is present, append BALANCE line
    if (sale.changeAmount > 0) {
      transPay.add({
        'id': payId++,
        'PayMode': 'BALANCE',
        'payMode': 'BALANCE',
        'cardType': 'BALANCE',
        'cardRef': '',
        'amount': sale.changeAmount,
      });
    }

    // Closing SUB TOTAL 0 line
    transPay.add({
      'id': payId++,
      'PayMode': 'SUB TOTAL',
      'payMode': 'SUB TOTAL',
      'cardType': 'SUB TOTAL',
      'cardRef': '',
      'amount': 0,
    });

    return {
      'loca': (locationCode != null && locationCode.isNotEmpty) ? locationCode : '01',
      'cuss_Code': customerCode ?? '',
      'user_Name': (userName != null && userName.isNotEmpty) ? userName : (sale.cashierName.isNotEmpty ? sale.cashierName : 'ONIMTA'),
      'unit': (unitCode != null && unitCode.isNotEmpty) ? unitCode : '01',
      'discount': sale.discount,
      'refDocNo': sale.invoiceNo,
      'transDt': transDt,
      'transPay': transPay,
      'recNo': sale.invoiceNo,
      'mobileNo': customerPhone ?? '',
      'billStatus': '',
      'salesMan': (salesman != null && salesman.isNotEmpty) ? salesman : 'Default',
    };
  }

  @override
  Future<Map<String, dynamic>> syncSale(
    Sale sale, {
    String? userName,
    String? customerCode,
    String? customerPhone,
    String? salesman,
    String? baseUrl,
    bool? isDiscountPercentage,
  }) async {
    final payload = buildBillPayload(
      sale,
      userName: userName,
      customerCode: customerCode,
      customerPhone: customerPhone,
      salesman: salesman,
      isDiscountPercentage: isDiscountPercentage,
    );

    try {
      final response = await _remoteDataSource.sendBillSave(payload, baseUrl: baseUrl);

      if (sale.id != null) {
        final syncedTime = DateTime.now().toIso8601String();
        await _salesRepository.markSaleSynced(sale.id!, syncedTime);
      }

      await _syncLogRepository.logAction(
        actionType: 'BILL_SYNC',
        title: 'Bill Synced to ERP: ${sale.invoiceNo}',
        details: 'Invoice: ${sale.invoiceNo} | Total: ${sale.grandTotal.toStringAsFixed(2)} | Items: ${sale.items.length}',
        status: 'SUCCESS',
        responseBody: response,
      );

      return {
        'success': true,
        'invoiceNo': sale.invoiceNo,
        'response': response,
      };
    } catch (e) {
      await _syncLogRepository.logAction(
        actionType: 'BILL_SYNC',
        title: 'Bill Sync Failed: ${sale.invoiceNo}',
        details: 'Invoice: ${sale.invoiceNo} | Total: ${sale.grandTotal.toStringAsFixed(2)} | Items: ${sale.items.length}',
        status: 'FAILED',
        errorMessage: e.toString(),
      );

      return {
        'success': false,
        'invoiceNo': sale.invoiceNo,
        'error': e.toString(),
      };
    }
  }

  @override
  Future<Map<String, dynamic>> syncPendingSales({String? baseUrl}) async {
    final unsynced = await _salesRepository.getUnsyncedSales();
    if (unsynced.isEmpty) {
      return {'total': 0, 'synced': 0, 'failed': 0};
    }

    int syncedCount = 0;
    int failedCount = 0;

    for (final sale in unsynced) {
      final result = await syncSale(sale, baseUrl: baseUrl);
      if (result['success'] == true) {
        syncedCount++;
      } else {
        failedCount++;
      }
    }

    return {
      'total': unsynced.length,
      'synced': syncedCount,
      'failed': failedCount,
    };
  }
}
