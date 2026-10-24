import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';

abstract class ShiftRemoteDataSource {
  Future<Map<String, dynamic>> sendDayEnd({
    String? baseUrl,
    String location = '01',
    String unit = '01',
    String? dayStartDate,
  });
}

class ShiftRemoteDataSourceImpl implements ShiftRemoteDataSource {
  final ApiService _apiService;

  ShiftRemoteDataSourceImpl(this._apiService);

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      final now = DateTime.now();
      return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year.toString().padLeft(4, '0')}';
    }
    final clean = rawDate.trim();
    final dt = DateTime.tryParse(clean);
    if (dt != null) {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().padLeft(4, '0')}';
    }

    final datePart = clean.contains('T')
        ? clean.split('T')[0]
        : clean.contains(' ')
            ? clean.split(' ')[0]
            : clean;

    final parts = datePart.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      // If already in DD-MM-YYYY or DD/MM/YYYY
      if (parts[0].length <= 2 && parts[2].length == 4) {
        return '${parts[0].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[2]}';
      }
      // If YYYY-MM-DD or YYYY/MM/DD
      if (parts[0].length == 4 && parts[2].length <= 2) {
        return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
      }
    }
    return clean;
  }

  @override
  Future<Map<String, dynamic>> sendDayEnd({
    String? baseUrl,
    String location = '01',
    String unit = '01',
    String? dayStartDate,
  }) async {
    final effectiveLocation = location.trim().isNotEmpty ? location.trim() : '01';
    final effectiveUnit = unit.trim().isNotEmpty ? unit.trim() : '01';
    final formattedDate = _formatDate(dayStartDate);

    final payload = [
      {
        'para_Name': '@Iid',
        'para_Type': 'int',
        'para_Lenth': 7,
        'para_Direction': 'Input',
        'para_Data': 7,
      },
      {
        'para_Name': '@Text1',
        'para_Type': 'varchar',
        'para_Lenth': 5000,
        'para_Direction': 'Input',
        'para_Data': effectiveLocation,
      },
      {
        'para_Name': '@Text2',
        'para_Type': 'varchar',
        'para_Lenth': 100,
        'para_Direction': 'Input',
        'para_Data': effectiveUnit,
      },
      {
        'para_Name': '@Text3',
        'para_Type': 'varchar',
        'para_Lenth': 100,
        'para_Direction': 'Input',
        'para_Data': formattedDate,
      },
      {
        'para_Name': '@Text4',
        'para_Type': 'varchar',
        'para_Lenth': 100,
        'para_Direction': 'Input',
        'para_Data': '',
      },
    ];

    // Retry up to 2 times automatically in case of initial cold start / connection timeout
    dynamic lastError;
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final res = await _apiService.executeCommonSp(
          baseUrl: baseUrl,
          spName: 'sp_Android_Common_API',
          con: '1',
          hasReturnData: 'T',
          parameters: payload,
        );

        final returnVal = res['strReturnRes'] ?? res['StrReturnRes'] ?? res['returnRes'] ?? res['success'];
        if (returnVal != null) {
          final isFail = returnVal == false || returnVal == 'false' || returnVal == 0 || returnVal == '0';
          if (isFail) {
            final serverMsg = res['strReturnMsg'] ??
                res['StrReturnMsg'] ??
                res['strError'] ??
                res['error'] ??
                res['errorMessage'] ??
                res['message'] ??
                'ERP server rejected Day End (Iid 7)';
            throw Exception(serverMsg);
          }
        }

        return res;
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          debugPrint('sendDayEnd attempt $attempt failed ($e), retrying in 1.5s...');
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }

    throw lastError ?? Exception('Day End API failed after retries');
  }
}
