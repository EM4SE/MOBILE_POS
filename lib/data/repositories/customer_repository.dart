import '../datasources/local/customer_local_datasource.dart';
import '../models/customer_model.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getCustomers({String? searchQuery, int? limit, int? offset});
  Future<Customer?> getCustomerById(int id);
  Future<int> insertCustomer(Customer customer);
  Future<int> updateCustomer(Customer customer);
  Future<int> deleteCustomer(int id);
  Future<int> countCustomers({String? searchQuery});
}

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerLocalDataSource _localDataSource;

  CustomerRepositoryImpl(this._localDataSource);

  @override
  Future<List<Customer>> getCustomers({
    String? searchQuery,
    int? limit,
    int? offset,
  }) {
    return _localDataSource.getCustomers(
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Customer?> getCustomerById(int id) {
    return _localDataSource.getCustomerById(id);
  }

  @override
  Future<int> insertCustomer(Customer customer) {
    return _localDataSource.insertCustomer(customer);
  }

  @override
  Future<int> updateCustomer(Customer customer) {
    return _localDataSource.updateCustomer(customer);
  }

  @override
  Future<int> deleteCustomer(int id) {
    return _localDataSource.deleteCustomer(id);
  }

  @override
  Future<int> countCustomers({String? searchQuery}) {
    return _localDataSource.countCustomers(searchQuery: searchQuery);
  }
}
