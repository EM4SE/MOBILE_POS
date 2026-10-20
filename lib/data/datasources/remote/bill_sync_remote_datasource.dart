import '../../../core/services/api_service.dart';

abstract class BillSyncRemoteDataSource {
  Future<Map<String, dynamic>> sendBillSave(
    Map<String, dynamic> billPayload, {
    String? baseUrl,
  });
}

class BillSyncRemoteDataSourceImpl implements BillSyncRemoteDataSource {
  final ApiService _apiService;

  BillSyncRemoteDataSourceImpl(this._apiService);

  @override
  Future<Map<String, dynamic>> sendBillSave(
    Map<String, dynamic> billPayload, {
    String? baseUrl,
  }) async {
    return await _apiService.postJson(
      baseUrl: baseUrl,
      path: '/api/Pos/POSBillSave',
      body: billPayload,
    );
  }
}
