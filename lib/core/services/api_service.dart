import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Generic RPC Service to call the centralized Stored Procedure endpoint
class ApiService {
  static const String defaultBaseUrl = 'http://194.233.76.58:9696';
  static String _activeBaseUrl = defaultBaseUrl;

  /// Returns currently active configured base URL (or default if not set)
  static String get baseUrl =>
      _activeBaseUrl.isNotEmpty ? _activeBaseUrl : defaultBaseUrl;

  /// Sets the active base URL. If null or empty, falls back to defaultBaseUrl.
  static void setBaseUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      String clean = url.trim();
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      _activeBaseUrl = clean;
    } else {
      _activeBaseUrl = defaultBaseUrl;
    }
  }

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..maxConnectionsPerHost = 25
    ..idleTimeout = const Duration(seconds: 15);

  /// Tests connectivity to a given baseUrl (or the configured baseUrl)
  Future<bool> testConnection({String? testUrl}) async {
    try {
      final target = (testUrl != null && testUrl.trim().isNotEmpty)
          ? testUrl.trim()
          : baseUrl;
      final cleanBase = target.endsWith('/')
          ? target.substring(0, target.length - 1)
          : target;
      final uri = Uri.parse('$cleanBase/api/Master/CommonExecute');
      final request =
          await _httpClient.postUrl(uri).timeout(const Duration(seconds: 7));
      request.headers.set(
          HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      request.add(utf8.encode(jsonEncode({
        'spName': 'sp_Android_Common_API',
        'con': '1',
        'hasReturnData': 'T',
        'parameters': [
          {
            'para_Name': '@Iid',
            'para_Type': 'int',
            'para_Direction': 'Input',
            'para_Data': '3'
          },
        ],
      })));
      final response =
          await request.close().timeout(const Duration(seconds: 7));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// Executes stored procedures via /api/master/CommonExecute
  Future<Map<String, dynamic>> executeCommonSp({
    String? baseUrl,
    required String spName,
    required String con,
    required String hasReturnData,
    required List<Map<String, dynamic>> parameters,
  }) async {
    final effectiveBase = (baseUrl != null && baseUrl.trim().isNotEmpty)
        ? baseUrl.trim()
        : ApiService.baseUrl;
    final cleanBase = effectiveBase.endsWith('/')
        ? effectiveBase.substring(0, effectiveBase.length - 1)
        : effectiveBase;
    final uri = Uri.parse('$cleanBase/api/Master/CommonExecute');

    final payload = jsonEncode({
      'spName': spName,
      'con': con,
      'hasReturnData': hasReturnData,
      'parameters': parameters,
    });

    final request = await _httpClient.postUrl(uri);
    request.headers
        .set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
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
      throw HttpException(
          'Server returned error ${response.statusCode}: $responseBody',
          uri: uri);
    }
  }

  /// Sends raw JSON payload to a REST endpoint (e.g. /api/Pos/POSBillSave)
  Future<Map<String, dynamic>> postJson({
    String? baseUrl,
    required String path,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final effectiveBase = (baseUrl != null && baseUrl.trim().isNotEmpty)
        ? baseUrl.trim()
        : ApiService.baseUrl;
    final cleanBase = effectiveBase.endsWith('/')
        ? effectiveBase.substring(0, effectiveBase.length - 1)
        : effectiveBase;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$cleanBase$cleanPath');

    final payload = jsonEncode(body);
    final request = await _httpClient.postUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.add(utf8.encode(payload));

    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (responseBody.trim().isEmpty) return {};
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'result': decoded};
      } catch (_) {
        return {'raw': responseBody};
      }
    } else {
      throw HttpException(
        'Server returned error ${response.statusCode}: $responseBody',
        uri: uri,
      );
    }
  }
}
