import '../datasources/local/product_local_datasource.dart';
import '../models/product_model.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({String? searchQuery, bool onlyActive = true, int? limit, int? offset});
  Future<Product?> getProductById(int id);
  Future<Product?> getProductByCode(String code);
  Future<Product?> getProductByBarcode(String barcode);
  Future<int> insertProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<int> countProducts({String? searchQuery, bool onlyActive = true});
}

class ProductRepositoryImpl implements ProductRepository {
  final ProductLocalDataSource _localDataSource;

  ProductRepositoryImpl(this._localDataSource);

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
  Future<Product?> getProductByCode(String code) {
    return _localDataSource.getProductByCode(code);
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) {
    return _localDataSource.getProductByBarcode(barcode);
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
}
