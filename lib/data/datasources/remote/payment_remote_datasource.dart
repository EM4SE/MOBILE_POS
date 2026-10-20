import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../models/payment_type_model.dart';

abstract class PaymentRemoteDataSource {
  Future<List<PaymentType>> fetchPaymentTypesFromApi({String? baseUrl});
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final ApiService _apiService;

  PaymentRemoteDataSourceImpl(this._apiService);

  @override
  Future<List<PaymentType>> fetchPaymentTypesFromApi({String? baseUrl}) async {
    final effectiveBaseUrl = (baseUrl != null && baseUrl.trim().isNotEmpty)
        ? baseUrl.trim()
        : ApiService.baseUrl;

    try {
      final res = await _apiService.executeCommonSp(
        baseUrl: effectiveBaseUrl,
        spName: 'sp_Android_Common_API',
        con: '1',
        hasReturnData: 'T',
        parameters: [
          {
            'para_Name': '@Iid',
            'para_Type': 'int',
            'para_Lenth': '26',
            'para_Direction': 'Input',
            'para_Data': '26',
          },
          {
            'para_Name': '@Text1',
            'para_Type': 'varchar',
            'para_Lenth': 5000,
            'para_Direction': 'Input',
            'para_Data': '',
          },
          {
            'para_Name': '@Text2',
            'para_Type': 'varchar',
            'para_Lenth': 100,
            'para_Direction': 'Input',
            'para_Data': '',
          },
          {
            'para_Name': '@Text3',
            'para_Type': 'varchar',
            'para_Lenth': 100,
            'para_Direction': 'Input',
            'para_Data': '',
          },
          {
            'para_Name': '@Text4',
            'para_Type': 'varchar',
            'para_Lenth': 100,
            'para_Direction': 'Input',
            'para_Data': '',
          },
        ],
      );

      final dynamic commonResult = res['CommonResult'] ?? res['commonResult'];
      final List<PaymentType> list = [];

      List<dynamic> rows = const [];
      if (commonResult is List) {
        rows = commonResult;
      } else if (commonResult is Map) {
        for (final entry in commonResult.entries) {
          if (entry.key.toString().toLowerCase().contains('table') && entry.value is List) {
            rows = entry.value as List;
            break;
          }
        }
      }

      for (final r in rows) {
        if (r is Map<String, dynamic>) {
          final pt = PaymentType.fromJson(r);
          if (pt.description.isNotEmpty && !pt.isCash) {
            list.add(pt);
          }
        } else if (r is Map) {
          final pt = PaymentType.fromJson(Map<String, dynamic>.from(r));
          if (pt.description.isNotEmpty && !pt.isCash) {
            list.add(pt);
          }
        }
      }

      debugPrint('PaymentRemoteDataSource: Successfully fetched ${list.length} paytypes via iid 26');
      return list;
    } catch (e) {
      debugPrint('PaymentRemoteDataSource: Failed to fetch paytypes: $e');
      rethrow;
    }
  }
}
