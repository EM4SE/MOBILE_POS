import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Generic RPC Service to call the centralized Stored Procedure endpoint
class ApiService {
  static const String defaultBaseUrl = 'http://194.233.76.58:9696';
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..maxConnectionsPerHost = 25
    ..idleTimeout = const Duration(seconds: 15);

  /// Executes stored procedures via /api/AndroidApi/CommonExecute
  Future<Map<String, dynamic>> executeCommonSp({
    String baseUrl = defaultBaseUrl,
    required String spName,
    required String con,
    required String hasReturnData,
    required List<Map<String, dynamic>> parameters,
  }) async {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$cleanBase/api/AndroidApi/CommonExecute');
    
    final payload = jsonEncode({
      'spName': spName,
      'con': con,
      'hasReturnData': hasReturnData,
      'parameters': parameters,
    });

    final request = await _httpClient.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.add(utf8.encode(payload));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        throw FormatException('Unexpected response format: $responseBody');
      }
    } else {
      throw HttpException('Server returned error ${response.statusCode}: $responseBody', uri: uri);
    }
  }
}
