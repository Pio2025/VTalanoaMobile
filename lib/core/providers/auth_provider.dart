import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;

  AuthStatus get status => _status;
  UserModel?  get user   => _user;
  String?     get error  => _error;
  bool        get isAuth => _status == AuthStatus.authenticated;

  Future<void> checkSession() async {
    final token = await ApiService.getToken();
    if (token == null) { _set(AuthStatus.unauthenticated); return; }
    final u = await _service.getCurrentUser();
    _user = u;
    _set(u != null ? AuthStatus.authenticated : AuthStatus.unauthenticated);
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      final result = await _service.login(email, password);
      _user = result.user;
      _set(AuthStatus.authenticated);
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _error = null;
    try {
      final result = await _service.register(name: name, email: email, password: password);
      _user = result.user;
      _set(AuthStatus.authenticated);
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _set(AuthStatus.unauthenticated);
  }

  void _set(AuthStatus s) { _status = s; notifyListeners(); }

  String _parseError(Object e) {
    // Dio wraps server responses — extract the message if present
    final str = e.toString();
    if (str.contains('Invalid credentials')) return 'Invalid email or password.';
    if (str.contains('already')) return 'An account with this email already exists.';
    return 'Something went wrong. Please try again.';
  }
}
