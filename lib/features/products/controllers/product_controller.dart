import 'package:flutter/foundation.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';

/// Controller managing product inventory state, search filters, and CRUD operations
class ProductController extends ChangeNotifier {
  final ProductRepository _productRepository;

  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _onlyActive = false;
  String? _errorMessage;

  ProductController(this._productRepository);

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  bool get onlyActive => _onlyActive;
  String? get errorMessage => _errorMessage;

  Future<void> loadProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _productRepository.getProducts(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        onlyActive: _onlyActive,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load products: $e';
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      loadProducts();
    }
  }

  void toggleOnlyActive(bool onlyActive) {
    if (_onlyActive != onlyActive) {
      _onlyActive = onlyActive;
      loadProducts();
    }
  }

  Future<bool> saveProduct({
    int? id,
    required String code,
    required String barcode,
    required String description,
    required double price,
    required double cost,
    required bool active,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final product = Product(
        id: id,
        code: code.trim(),
        barcode: barcode.trim(),
        description: description.trim(),
        price: price,
        cost: cost,
        active: active,
      );

      if (id == null) {
        await _productRepository.insertProduct(product);
      } else {
        await _productRepository.updateProduct(product);
      }

      await loadProducts();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save product: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await _productRepository.deleteProduct(id);
      await loadProducts();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete product: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleProductActive(Product product) async {
    try {
      final updated = product.copyWith(active: !product.active);
      await _productRepository.updateProduct(updated);
      await loadProducts();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to toggle status: $e';
      notifyListeners();
      return false;
    }
  }
}
