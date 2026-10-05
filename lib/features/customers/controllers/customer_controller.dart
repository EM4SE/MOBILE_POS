import 'package:flutter/foundation.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/customer_repository.dart';

/// Controller managing customer directory state, search queries, and CRUD operations
class CustomerController extends ChangeNotifier {
  final CustomerRepository _customerRepository;

  List<Customer> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;

  CustomerController(this._customerRepository);

  List<Customer> get customers => List.unmodifiable(_customers);
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  Future<void> loadCustomers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _customers = await _customerRepository.getCustomers(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load customers: $e';
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      loadCustomers();
    }
  }

  Future<bool> saveCustomer({
    int? id,
    required String name,
    required String phone,
    required String email,
    required String address,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final customer = Customer(
        id: id,
        name: name.trim(),
        phone: phone.trim(),
        email: email.trim(),
        address: address.trim(),
      );

      if (id == null) {
        await _customerRepository.insertCustomer(customer);
      } else {
        await _customerRepository.updateCustomer(customer);
      }

      await loadCustomers();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save customer: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    try {
      await _customerRepository.deleteCustomer(id);
      await loadCustomers();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete customer: $e';
      notifyListeners();
      return false;
    }
  }
}
