import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../datasources/local/settings_local_datasource.dart';
import '../datasources/remote/payment_remote_datasource.dart';
import '../models/payment_type_model.dart';

abstract class PaymentTypeRepository {
  Future<List<PaymentType>> getPaymentTypes({bool forceRefresh = false, String? baseUrl});
  Future<List<PaymentType>> syncPaymentTypes({String? baseUrl});
}

class PaymentTypeRepositoryImpl implements PaymentTypeRepository {
  static const String _cachedPaytypesKey = 'cached_paytypes_json';

  final PaymentRemoteDataSource _remoteDataSource;
  final SettingsLocalDataSource _settingsLocalDataSource;

  PaymentTypeRepositoryImpl(
    this._remoteDataSource,
    this._settingsLocalDataSource,
  );

  @override
  Future<List<PaymentType>> getPaymentTypes({
    bool forceRefresh = false,
    String? baseUrl,
  }) async {
    // 1. If not forcing refresh, attempt to load from local cache first
    if (!forceRefresh) {
      final cachedJson = await _settingsLocalDataSource.getSetting(_cachedPaytypesKey);
      if (cachedJson != null && cachedJson.trim().isNotEmpty) {
        try {
          final List decoded = jsonDecode(cachedJson);
          final cachedTypes = <PaymentType>[];
          for (final item in decoded) {
            if (item is Map) {
              final pt = PaymentType.fromJson(Map<String, dynamic>.from(item));
              if (pt.description.isNotEmpty && !pt.isCash) {
                cachedTypes.add(pt);
              }
            }
          }

          if (cachedTypes.isNotEmpty) {
            // Trigger background refresh to keep cache fresh
            _syncInBackground(baseUrl);
            // Cash always kept as first ("cash keep as exist")
            return [PaymentType.cashDefault, ...cachedTypes];
          }
        } catch (e) {
          debugPrint('PaymentTypeRepository: Failed to parse cached paytypes: $e');
        }
      }
    }

    // 2. Fetch fresh from remote API
    try {
      final remoteTypes = await _remoteDataSource.fetchPaymentTypesFromApi(baseUrl: baseUrl);
      if (remoteTypes.isNotEmpty) {
        // Cache API types locally
        final jsonString = jsonEncode(remoteTypes.map((e) => e.toJson()).toList());
        await _settingsLocalDataSource.saveSetting(_cachedPaytypesKey, jsonString);
        return [PaymentType.cashDefault, ...remoteTypes];
      }
    } catch (e) {
      debugPrint('PaymentTypeRepository: Remote fetch failed ($e), attempting fallback.');
    }

    // 3. Fallback: check cache again in case forceRefresh failed
    final cachedJson = await _settingsLocalDataSource.getSetting(_cachedPaytypesKey);
    if (cachedJson != null && cachedJson.trim().isNotEmpty) {
      try {
        final List decoded = jsonDecode(cachedJson);
        final cachedTypes = <PaymentType>[];
        for (final item in decoded) {
          if (item is Map) {
            final pt = PaymentType.fromJson(Map<String, dynamic>.from(item));
            if (pt.description.isNotEmpty && !pt.isCash) {
              cachedTypes.add(pt);
            }
          }
        }
        if (cachedTypes.isNotEmpty) {
          return [PaymentType.cashDefault, ...cachedTypes];
        }
      } catch (_) {}
    }

    // 4. Ultimate offline default fallback
    return [PaymentType.cashDefault, ...PaymentType.fallbackApiTypes];
  }

  @override
  Future<List<PaymentType>> syncPaymentTypes({String? baseUrl}) async {
    return getPaymentTypes(forceRefresh: true, baseUrl: baseUrl);
  }

  void _syncInBackground(String? baseUrl) {
    _remoteDataSource.fetchPaymentTypesFromApi(baseUrl: baseUrl).then((remoteTypes) async {
      if (remoteTypes.isNotEmpty) {
        final jsonString = jsonEncode(remoteTypes.map((e) => e.toJson()).toList());
        await _settingsLocalDataSource.saveSetting(_cachedPaytypesKey, jsonString);
      }
    }).catchError((_) {});
  }
}
