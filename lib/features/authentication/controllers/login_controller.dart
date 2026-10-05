import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/authentication_service.dart';
import '../../../data/models/user_model.dart';

/// Controller managing login screen state, PIN collection, and authentication flow
class LoginController extends ChangeNotifier {
  final AuthenticationService _authService;

  String _pin = '';
  String? _errorMessage;
  bool _isLoading = false;

  LoginController(this._authService);

  String get pin => _pin;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get hasPin => _pin.isNotEmpty;

  void appendDigit(String digit) {
    if (_pin.length >= 8) return; // limit max pin length
    _pin += digit;
    _errorMessage = null;
    notifyListeners();
  }

  void backspace() {
    if (_pin.isNotEmpty) {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearPin() {
    if (_pin.isNotEmpty || _errorMessage != null) {
      _pin = '';
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<User?> login() async {
    if (_pin.isEmpty) {
      _errorMessage = 'Please enter your user PIN';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.loginWithPin(_pin);
      _isLoading = false;
      _pin = '';
      notifyListeners();
      return user;
    } on AppException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      _pin = '';
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred during login';
      _pin = '';
      notifyListeners();
      return null;
    }
  }
}
