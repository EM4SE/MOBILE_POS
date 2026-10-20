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
  });

  Future<Map<String, dynamic>> syncSale(
    Sale sale, {
    String? userName,
    String? customerCode,
    String? customerPhone,
    String? salesman,
    String? baseUrl,
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

    // First line is always SUB TOTAL
    transPay.add({
      'id': 1,
      'payMode': 'SUB TOTAL',
      'cardType': 'SUB TOTAL',
      'cardRef': '',
      'amount': sale.grandTotal,
    });

    int payId = 2;
    final breakdown = PaymentBreakdownHelper.parse(sale.paymentMethod, sale.paidAmount);

    if (breakdown.isNotEmpty) {
      for (final item in breakdown) {
        final mode = item.method.toUpperCase();
        transPay.add({
          'id': payId++,
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
        'payMode': 'BALANCE',
        'cardType': 'BALANCE',
        'cardRef': '',
        'amount': sale.changeAmount,
      });
    }

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
  }) async {
    final payload = buildBillPayload(
      sale,
      userName: userName,
      customerCode: customerCode,
      customerPhone: customerPhone,
      salesman: salesman,
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
