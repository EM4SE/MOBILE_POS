import '../../../app/constants/database_constants.dart';
import '../../../core/services/database_service.dart';
import '../../models/customer_model.dart';

abstract class CustomerLocalDataSource {
  Future<List<Customer>> getCustomers({String? searchQuery, int? limit, int? offset});
  Future<Customer?> getCustomerById(int id);
  Future<int> insertCustomer(Customer customer);
  Future<int> updateCustomer(Customer customer);
  Future<int> deleteCustomer(int id);
  Future<int> countCustomers({String? searchQuery});
}

class CustomerLocalDataSourceImpl implements CustomerLocalDataSource {
  final DatabaseService _databaseService;

  CustomerLocalDataSourceImpl(this._databaseService);

  @override
  Future<List<Customer>> getCustomers({
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    String? where;
    List<Object?>? args;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      where = '(${DatabaseConstants.colName} LIKE ? OR ${DatabaseConstants.colPhone} LIKE ? OR ${DatabaseConstants.colEmail} LIKE ?)';
      args = [term, term, term];
    }

    final results = await _databaseService.query(
      DatabaseConstants.tableCustomers,
      where: where,
      whereArgs: args,
      orderBy: '${DatabaseConstants.colName} ASC',
      limit: limit,
      offset: offset,
    );

    return results.map(Customer.fromMap).toList();
  }

  @override
  Future<Customer?> getCustomerById(int id) async {
    final results = await _databaseService.query(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Customer.fromMap(results.first);
  }

  @override
  Future<int> insertCustomer(Customer customer) async {
    return await _databaseService.insert(
      DatabaseConstants.tableCustomers,
      customer.toMap(),
    );
  }

  @override
  Future<int> updateCustomer(Customer customer) async {
    return await _databaseService.update(
      DatabaseConstants.tableCustomers,
      customer.toMap(),
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [customer.id],
    );
  }

  @override
  Future<int> deleteCustomer(int id) async {
    return await _databaseService.delete(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> countCustomers({String? searchQuery}) async {
    String where = '';
    List<Object?>? args;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      where = 'WHERE (${DatabaseConstants.colName} LIKE ? OR ${DatabaseConstants.colPhone} LIKE ? OR ${DatabaseConstants.colEmail} LIKE ?)';
      args = [term, term, term];
    }

    final sql = 'SELECT COUNT(*) as total FROM ${DatabaseConstants.tableCustomers} $where';
    final result = await _databaseService.rawQuery(sql, args);
    if (result.isNotEmpty) {
      return (result.first['total'] as int?) ?? 0;
    }
    return 0;
  }
}
