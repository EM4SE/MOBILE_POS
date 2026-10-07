import '../../../app/constants/database_constants.dart';
import '../../../core/services/database_service.dart';
import '../../models/product_model.dart';

abstract class ProductLocalDataSource {
  Future<List<Product>> getProducts({String? searchQuery, bool onlyActive = true, int? limit, int? offset});
  Future<Product?> getProductById(int id);
  Future<Product?> getProductByCode(String code);
  Future<Product?> getProductByBarcode(String barcode);
  Future<int> insertProduct(Product product);
  Future<int> insertProducts(List<Product> products);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<int> countProducts({String? searchQuery, bool onlyActive = true});
}

class ProductLocalDataSourceImpl implements ProductLocalDataSource {
  final DatabaseService _databaseService;

  ProductLocalDataSourceImpl(this._databaseService);

  @override
  Future<List<Product>> getProducts({
    String? searchQuery,
    bool onlyActive = true,
    int? limit,
    int? offset,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (onlyActive) {
      conditions.add('${DatabaseConstants.colActive} = 1');
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      conditions.add(
        '(${DatabaseConstants.colDescription} LIKE ? OR ${DatabaseConstants.colCode} LIKE ? OR ${DatabaseConstants.colBarcode} LIKE ? OR ${DatabaseConstants.colIsbn} LIKE ?)',
      );
      args.addAll([term, term, term, term]);
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final results = await _databaseService.query(
      DatabaseConstants.tableProducts,
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: '${DatabaseConstants.colDescription} ASC',
      limit: limit,
      offset: offset,
    );

    return results.map(Product.fromMap).toList();
  }

  @override
  Future<Product?> getProductById(int id) async {
    final results = await _databaseService.query(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  @override
  Future<Product?> getProductByCode(String code) async {
    final clean = code.trim();
    final results = await _databaseService.query(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.colCode} = ? OR ${DatabaseConstants.colBarcode} = ? OR ${DatabaseConstants.colIsbn} = ?',
      whereArgs: [clean, clean, clean],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final clean = barcode.trim();
    final results = await _databaseService.query(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.colBarcode} = ? OR ${DatabaseConstants.colIsbn} = ? OR ${DatabaseConstants.colCode} = ?',
      whereArgs: [clean, clean, clean],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  @override
  Future<int> insertProduct(Product product) async {
    return await _databaseService.insert(
      DatabaseConstants.tableProducts,
      product.toMap(),
    );
  }

  @override
  Future<int> insertProducts(List<Product> products) async {
    if (products.isEmpty) return 0;
    return await _databaseService.insertBatch(
      DatabaseConstants.tableProducts,
      products.map((p) => p.toMap()).toList(),
    );
  }

  @override
  Future<int> updateProduct(Product product) async {
    return await _databaseService.update(
      DatabaseConstants.tableProducts,
      product.toMap(),
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [product.id],
    );
  }

  @override
  Future<int> deleteProduct(int id) async {
    return await _databaseService.delete(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> countProducts({String? searchQuery, bool onlyActive = true}) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (onlyActive) {
      conditions.add('${DatabaseConstants.colActive} = 1');
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      conditions.add(
        '(${DatabaseConstants.colDescription} LIKE ? OR ${DatabaseConstants.colCode} LIKE ? OR ${DatabaseConstants.colBarcode} LIKE ? OR ${DatabaseConstants.colIsbn} LIKE ?)',
      );
      args.addAll([term, term, term, term]);
    }

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final sql = 'SELECT COUNT(*) as total FROM ${DatabaseConstants.tableProducts} $where';

    final result = await _databaseService.rawQuery(sql, args);
    if (result.isNotEmpty) {
      return (result.first['total'] as int?) ?? 0;
    }
    return 0;
  }
}
