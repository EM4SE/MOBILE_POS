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
      return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    final clean = rawDate.trim();
    final dt = DateTime.tryParse(clean);
    if (dt != null) {
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    if (clean.contains('T')) {
      return clean.split('T')[0];
    }
    if (clean.contains(' ')) {
      return clean.split(' ')[0];
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

    return await _apiService.executeCommonSp(
      baseUrl: baseUrl,
      spName: 'sp_Android_Common_API',
      con: '1',
      hasReturnData: 'T',
      parameters: [
        {
          'para_Name': '@Iid',
          'para_Type': 'int',
          'para_Lenth': '7',
          'para_Direction': 'Input',
          'para_Data': '7',
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
      ],
    );
  }
}
