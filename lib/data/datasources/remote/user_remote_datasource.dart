import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../models/user_model.dart';

abstract class UserRemoteDataSource {
  Future<List<User>> fetchCashiersFromApi({String? baseUrl});
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final ApiService _apiService;

  UserRemoteDataSourceImpl(this._apiService);

  @override
  Future<List<User>> fetchCashiersFromApi({String? baseUrl}) async {
    final effectiveBaseUrl = (baseUrl != null && baseUrl.trim().isNotEmpty)
        ? baseUrl.trim()
        : ApiService.baseUrl;

    debugPrint('Fetching cashiers via sp_Android_Common_API @Iid=8 from $effectiveBaseUrl');

    final res = await _apiService.executeCommonSp(
      baseUrl: effectiveBaseUrl,
      spName: 'sp_Android_Common_API',
      con: '1',
      hasReturnData: 'T',
      parameters: [
        {
          'para_Name': '@Iid',
          'para_Type': 'int',
          'para_Lenth': '8',
          'para_Direction': 'Input',
          'para_Data': '8',
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

    final isSuccess = res['strReturnRes'] == true || res['strReturnRes'] == 'true';
    if (!isSuccess) {
      throw Exception('ERP API returned error for cashiers (Iid 8)');
    }

    final commonResult = res['CommonResult'] as List?;
    if (commonResult == null) {
      return [];
    }

    final users = <User>[];
    for (final item in commonResult) {
      if (item is Map) {
        final username = (item['USER_NAME'] ?? item['user_Name'] ?? '').toString().trim();
        final pin = (item['Pass_Word'] ?? item['pass_Word'] ?? item['password'] ?? '').toString().trim();
        final adminVal = (item['isAdmin'] ?? item['IsAdmin'] ?? '').toString().trim().toUpperCase();
        final isAdmin = adminVal == 'T' || adminVal == 'TRUE' || adminVal == '1';

        if (username.isNotEmpty) {
          users.add(User(
            username: username,
            displayName: username,
            pin: pin,
            role: isAdmin ? 'ADMIN' : 'CASHIER',
            active: true,
          ));
        }
      }
    }

    debugPrint('Successfully parsed ${users.length} cashiers from ERP Iid 8');
    return users;
  }
}
