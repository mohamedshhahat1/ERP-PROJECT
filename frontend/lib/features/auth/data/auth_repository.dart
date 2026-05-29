import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import 'models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref.read(storageProvider));
});

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepository(this._dio, this._storage);

  Future<AuthToken> login(String username, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    final token = AuthToken.fromJson(response.data);
    await _storage.write(key: 'access_token', value: token.accessToken);
    await _storage.write(key: 'user_id', value: token.userId.toString());
    await _storage.write(key: 'user_role', value: token.role);
    await _storage.write(key: 'user_name', value: token.fullName);
    return token;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return false;
    // Decode JWT payload to check expiry (JWT is base64url: header.payload.sig)
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final exp = data['exp'] as int?;
      if (exp == null) return false;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Consider token valid if it has at least 1 minute remaining
      return expiryDate.isAfter(DateTime.now().add(const Duration(minutes: 1)));
    } catch (_) {
      return false;
    }
  }

  Future<String?> getToken() => _storage.read(key: 'access_token');
  Future<String?> getUserRole() => _storage.read(key: 'user_role');
  Future<String?> getUserName() => _storage.read(key: 'user_name');

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }
}
