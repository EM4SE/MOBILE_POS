import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../exceptions/app_exceptions.dart';

abstract class AuthenticationService {
  ValueListenable<User?> get currentUser;
  bool get isAuthenticated;
  Future<User> loginWithPin(String pin);
  void logout();
}

class AuthenticationServiceImpl implements AuthenticationService {
  final UserRepository _userRepository;
  final ValueNotifier<User?> _currentUser = ValueNotifier<User?>(null);

  AuthenticationServiceImpl(this._userRepository);

  @override
  ValueListenable<User?> get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser.value != null;

  @override
  Future<User> loginWithPin(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) {
      throw const AuthenticationException('PIN cannot be empty');
    }

    final user = await _userRepository.authenticateByPin(cleanPin);
    if (user == null) {
      throw const AuthenticationException('Invalid PIN. Please try again.');
    }

    if (!user.active) {
      throw const AuthenticationException('User account is deactivated. Contact Admin.');
    }

    _currentUser.value = user;
    return user;
  }

  @override
  void logout() {
    _currentUser.value = null;
  }
}
