import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.read(dioProvider));
});

class UserModel {
  final int userId;
  final String fullName;
  final String username;
  final String role;
  final bool activeStatus;

  UserModel({required this.userId, required this.fullName, required this.username, required this.role, required this.activeStatus});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    userId: json['user_id'] ?? 0,
    fullName: json['full_name'] ?? '',
    username: json['username'] ?? '',
    role: json['role'] ?? '',
    activeStatus: json['active_status'] ?? true,
  );
}

class UsersRepository {
  final Dio _dio;
  UsersRepository(this._dio);

  Future<List<UserModel>> getAll() async {
    final response = await _dio.get('/users');
    return (response.data as List).map((e) => UserModel.fromJson(e)).toList();
  }

  Future<UserModel> create({required String fullName, required String username, required String password, required String role}) async {
    final response = await _dio.post('/auth/register', data: {
      'full_name': fullName, 'username': username, 'password': password, 'role': role,
    });
    return UserModel.fromJson(response.data);
  }

  Future<void> deactivate(int userId) async {
    await _dio.put('/users/$userId/deactivate');
  }

  Future<void> activate(int userId) async {
    await _dio.put('/users/$userId/activate');
  }

  Future<Map<String, dynamic>> resetPassword(int userId) async {
    final response = await _dio.put('/users/$userId/reset-password');
    return response.data as Map<String, dynamic>;
  }
}
