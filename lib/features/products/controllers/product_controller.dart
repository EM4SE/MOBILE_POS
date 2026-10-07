import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';

/// Controller managing product inventory state, pagination, debounced search, and CRUD operations
class ProductController extends ChangeNotifier {
  final ProductRepository _productRepository;

  static const int pageSize = 30;

  List<Product> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  String _searchQuery = '';
  bool _onlyActive = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  ProductController(this._productRepository);

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  String get searchQuery => _searchQuery;
  bool get onlyActive => _onlyActive;
  String? get errorMessage => _errorMessage;

  /// Load first page of products (or reload with new search/filter)
  Future<void> loadProducts({bool refresh = true}) async {
    if (refresh) {
      _isLoading = true;
      _hasMore = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final query = _searchQuery.trim().isEmpty ? null : _searchQuery.trim();
      _totalCount = await _productRepository.countProducts(
        searchQuery: query,
        onlyActive: _onlyActive,
      );

      final initialList = await _productRepository.getProducts(
        searchQuery: query,
        onlyActive: _onlyActive,
        limit: pageSize,
        offset: 0,
      );

      _products = initialList;
      _hasMore = _products.length < _totalCount;
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = 'Failed to load products: $e';
      notifyListeners();
    }
  }

  /// Load next page when scrolling reaches near bottom
  Future<void> loadMoreProducts() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final query = _searchQuery.trim().isEmpty ? null : _searchQuery.trim();
      final more = await _productRepository.getProducts(
        searchQuery: query,
        onlyActive: _onlyActive,
        limit: pageSize,
        offset: _products.length,
      );

      if (more.isEmpty) {
        _hasMore = false;
      } else {
        _products.addAll(more);
        _hasMore = _products.length < _totalCount;
      }
    } catch (e) {
      debugPrint('ProductController loadMore error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<int> syncProductsFromApi({String? baseUrl}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final count = await _productRepository.syncProductsFromApi(baseUrl: baseUrl);
      await loadProducts(refresh: true);
      return count;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Sync failed: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Debounced search query
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      loadProducts(refresh: true);
    });
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _searchQuery = '';
    loadProducts(refresh: true);
  }

  void toggleOnlyActive(bool onlyActive) {
    if (_onlyActive != onlyActive) {
      _onlyActive = onlyActive;
      loadProducts(refresh: true);
    }
  }

  Future<bool> saveProduct({
    int? id,
    required String code,
    required String barcode,
    String isbn = '',
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
        isbn: isbn.trim(),
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

      await loadProducts(refresh: true);
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
      await loadProducts(refresh: true);
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
      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to toggle status: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
