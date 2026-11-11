import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/sync_log_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../exceptions/app_exceptions.dart';

abstract class AuthenticationService {
  ValueListenable<User?> get currentUser;
  bool get isAuthenticated;
  Future<User> loginWithPin(String pin);
  Future<User> verifyPin(String pin);
  Future<List<User>> verifyUsersByPin(String pin);
  void logout({String reason = 'Manual Logout'});
  Future<List<User>> getAllUsers();
  Future<List<User>> syncCashiersFromApi({String? baseUrl});
}

class AuthenticationServiceImpl implements AuthenticationService {
  final UserRepository _userRepository;
  final SyncLogRepository? _syncLogRepository;
  final ValueNotifier<User?> _currentUser = ValueNotifier<User?>(null);

  AuthenticationServiceImpl(this._userRepository, [this._syncLogRepository]);

  @override
  ValueListenable<User?> get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser.value != null;

  @override
  Future<User> loginWithPin(String pin) async {
    try {
      final user = await verifyPin(pin);
      _currentUser.value = user;
      await _logAuthEvent(
        title: 'Cashier Login',
        details: 'User: ${user.displayName} (${user.username}) | Role: ${user.role}',
        status: 'SUCCESS',
      );
      return user;
    } on AppException catch (e) {
      await _logAuthEvent(
        title: 'Cashier Login Failed',
        details: 'Unsuccessful PIN login attempt',
        status: 'FAILED',
        errorMessage: e.message,
      );
      rethrow;
    } catch (e) {
      await _logAuthEvent(
        title: 'Cashier Login Error',
        details: 'Unexpected login failure',
        status: 'FAILED',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  @override
  Future<User> verifyPin(String pin) async {
    final activeUsers = await verifyUsersByPin(pin);
    return activeUsers.first;
  }

  @override
  Future<List<User>> verifyUsersByPin(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) {
      throw const AuthenticationException('PIN cannot be empty');
    }

    final matched = await _userRepository.getUsersByPin(cleanPin);
    if (matched.isEmpty) {
      throw const AuthenticationException('Invalid PIN. Please try again.');
    }

    final activeUsers = matched.where((u) => u.active).toList();
    if (activeUsers.isEmpty) {
      throw const AuthenticationException('User account is deactivated. Contact Admin.');
    }

    return activeUsers;
  }

  @override
  void logout({String reason = 'Manual Logout'}) {
    final previousUser = _currentUser.value;
    _currentUser.value = null;
    if (previousUser != null) {
      _logAuthEvent(
        title: 'Cashier Logout',
        details:
            'User: ${previousUser.displayName} (${previousUser.username}) | Role: ${previousUser.role} | Reason: $reason',
        status: 'SUCCESS',
      );
    }
  }

  Future<void> _logAuthEvent({
    required String title,
    String? details,
    required String status,
    String? errorMessage,
  }) async {
    try {
      await _syncLogRepository?.logAction(
        actionType: 'USER_AUTH',
        title: title,
        details: details,
        status: status,
        errorMessage: errorMessage,
      );
    } catch (_) {}
  }

  @override
  Future<List<User>> getAllUsers() {
    return _userRepository.getAllUsers();
  }

  @override
  Future<List<User>> syncCashiersFromApi({String? baseUrl}) {
    return _userRepository.fetchAndSyncCashiers(baseUrl: baseUrl);
  }
}
