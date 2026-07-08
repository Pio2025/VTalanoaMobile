import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final _api = ApiService();

  Future<({UserModel user, String token})> login(String email, String password) async {
    final resp = await _api.dio.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
    final token = resp.data['token'] as String;
    await ApiService.saveToken(token);
    return (user: UserModel.fromJson(resp.data['user']), token: token);
  }

  Future<({UserModel user, String token})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final resp = await _api.dio.post(ApiConstants.register, data: {
      'name': name,
      'email': email,
      'password': password,
    });
    final token = resp.data['token'] as String;
    await ApiService.saveToken(token);
    return (user: UserModel.fromJson(resp.data['user']), token: token);
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final resp = await _api.dio.get(ApiConstants.me);
      return UserModel.fromJson(resp.data['user'] ?? resp.data);
    } on DioException {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post(ApiConstants.logout);
    } catch (_) {}
    await ApiService.clearToken();
  }
}
