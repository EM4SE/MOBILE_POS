import 'package:flutter/foundation.dart';
import '../../../core/services/authentication_service.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/sync_log_repository.dart';

/// Controller managing customer directory state, search queries, and CRUD operations
class CustomerController extends ChangeNotifier {
  final CustomerRepository _customerRepository;
  final SyncLogRepository? _syncLogRepository;
  final AuthenticationService? _authService;

  List<Customer> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;

  CustomerController(
    this._customerRepository, [
    this._syncLogRepository,
    this._authService,
  ]);

  Future<void> _logAction(String title, String details) async {
    try {
      final cashier = _authService?.currentUser.value?.displayName ?? 'System';
      await _syncLogRepository?.logAction(
        actionType: 'POS_ACTION',
        title: title,
        details: 'Cashier: $cashier | $details',
        status: 'SUCCESS',
      );
    } catch (_) {}
  }

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
        _logAction('Customer Created', '${customer.name} (${customer.phone})');
      } else {
        await _customerRepository.updateCustomer(customer);
        _logAction('Customer Updated', 'ID: $id | ${customer.name} (${customer.phone})');
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
      _logAction('Customer Deleted', 'Customer ID: $id');
      await loadCustomers();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete customer: $e';
      notifyListeners();
      return false;
    }
  }
}
