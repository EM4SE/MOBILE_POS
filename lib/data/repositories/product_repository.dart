import 'package:flutter/foundation.dart';
import '../datasources/local/product_local_datasource.dart';
import '../datasources/remote/product_remote_datasource.dart';
import '../models/product_model.dart';
import 'sync_log_repository.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({String? searchQuery, bool onlyActive = true, int? limit, int? offset});
  Future<Product?> getProductById(int id);
  Future<Product?> getProductByCode(String code);
  Future<Product?> getProductByBarcode(String barcode);
  Future<int> insertProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<int> countProducts({String? searchQuery, bool onlyActive = true});
  
  /// Full catalog download across all departments & categories into SQLite
  Future<int> syncProductsFromApi({
    String? baseUrl,
    void Function(int count, String status)? onProgress,
  });

  /// Fast quick-catalog sync
  Future<int> syncQuickProductsFromApi({String? baseUrl});

  /// Fetch single product from API by code and cache to SQLite
  Future<Product?> fetchAndCacheProductByCode(String code, {String? baseUrl});
}

class ProductRepositoryImpl implements ProductRepository {
  final ProductLocalDataSource _localDataSource;
  final ProductRemoteDataSource _remoteDataSource;
  final SyncLogRepository? _syncLogRepository;

  ProductRepositoryImpl(
    this._localDataSource, [
    ProductRemoteDataSource? remoteDataSource,
    this._syncLogRepository,
  ]) : _remoteDataSource = remoteDataSource ?? ProductRemoteDataSourceImpl();

  @override
  Future<List<Product>> getProducts({
    String? searchQuery,
    bool onlyActive = true,
    int? limit,
    int? offset,
  }) {
    return _localDataSource.getProducts(
      searchQuery: searchQuery,
      onlyActive: onlyActive,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Product?> getProductById(int id) {
    return _localDataSource.getProductById(id);
  }

  @override
  Future<Product?> getProductByCode(String code) async {
    final local = await _localDataSource.getProductByCode(code);
    if (local != null) return local;

    // Online fallback if missing in local SQLite
    return await fetchAndCacheProductByCode(code);
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final local = await _localDataSource.getProductByBarcode(barcode);
    if (local != null) return local;

    // Online fallback
    return await fetchAndCacheProductByCode(barcode);
  }

  @override
  Future<int> insertProduct(Product product) {
    return _localDataSource.insertProduct(product);
  }

  @override
  Future<int> updateProduct(Product product) {
    return _localDataSource.updateProduct(product);
  }

  @override
  Future<int> deleteProduct(int id) {
    return _localDataSource.deleteProduct(id);
  }

  @override
  Future<int> countProducts({String? searchQuery, bool onlyActive = true}) {
    return _localDataSource.countProducts(
      searchQuery: searchQuery,
      onlyActive: onlyActive,
    );
  }

  @override
  Future<int> syncProductsFromApi({
    String? baseUrl,
    void Function(int count, String status)? onProgress,
  }) async {
    try {
      final remoteProducts = await _remoteDataSource.fetchAllProductsFromApi(
        baseUrl: baseUrl,
        onProgress: onProgress,
      );
      if (remoteProducts.isEmpty) return 0;

      onProgress?.call(remoteProducts.length, 'Saving ${remoteProducts.length} items to SQLite...');
      await _localDataSource.insertProducts(remoteProducts);
      debugPrint('ProductRepository: Saved ${remoteProducts.length} products to SQLite');

      await _syncLogRepository?.logAction(
        actionType: 'PRODUCT_SYNC',
        title: 'Product Catalog Synced',
        details: 'Downloaded and saved ${remoteProducts.length} products into SQLite',
        status: 'SUCCESS',
      );

      return remoteProducts.length;
    } catch (e) {
      debugPrint('ProductRepository sync error: $e');

      await _syncLogRepository?.logAction(
        actionType: 'PRODUCT_SYNC',
        title: 'Product Catalog Sync Failed',
        status: 'FAILED',
        errorMessage: e.toString(),
      );

      return 0;
    }
  }

  @override
  Future<int> syncQuickProductsFromApi({String? baseUrl}) async {
    try {
      final remoteProducts = await _remoteDataSource.fetchQuickProductsFromApi(baseUrl: baseUrl);
      if (remoteProducts.isEmpty) return 0;

      await _localDataSource.insertProducts(remoteProducts);
      debugPrint('ProductRepository: Fast synced ${remoteProducts.length} products to SQLite');

      await _syncLogRepository?.logAction(
        actionType: 'PRODUCT_SYNC',
        title: 'Quick Catalog Synced',
        details: 'Fast synced ${remoteProducts.length} products into SQLite',
        status: 'SUCCESS',
      );

      return remoteProducts.length;
    } catch (e) {
      debugPrint('ProductRepository quick sync error: $e');

      await _syncLogRepository?.logAction(
        actionType: 'PRODUCT_SYNC',
        title: 'Quick Catalog Sync Failed',
        status: 'FAILED',
        errorMessage: e.toString(),
      );

      return 0;
    }
  }

  @override
  Future<Product?> fetchAndCacheProductByCode(String code, {String? baseUrl}) async {
    try {
      final remoteProduct = await _remoteDataSource.fetchProductByCode(code, baseUrl: baseUrl);
      if (remoteProduct != null) {
        await _localDataSource.insertProduct(remoteProduct);
        return remoteProduct;
      }
    } catch (e) {
      debugPrint('ProductRepository fetchAndCacheProductByCode notice: $e');
    }
    return null;
  }
}
