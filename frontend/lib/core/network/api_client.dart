import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'exceptions.dart';

/// Base URL for the API. Override via environment or build config for production.
const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000/api');
const _storage = FlutterSecureStorage();

/// Whether a token refresh is currently in progress (prevents concurrent refreshes).
bool _isRefreshing = false;

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      // Attempt token refresh on 401 (not for auth endpoints themselves)
      if (error.response?.statusCode == 401 &&
          !error.requestOptions.path.contains('/auth/login') &&
          !error.requestOptions.path.contains('/auth/refresh') &&
          !_isRefreshing) {
        _isRefreshing = true;
        try {
          final refreshed = await _attemptTokenRefresh(dio);
          if (refreshed) {
            // Retry the original request with the new token
            final newToken = await _storage.read(key: 'access_token');
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newToken';
            final response = await dio.fetch(opts);
            _isRefreshing = false;
            return handler.resolve(response);
          }
        } catch (_) {
          // Refresh failed — fall through to normal error handling
        }
        _isRefreshing = false;
      }

      if (error.response != null) {
        final statusCode = error.response!.statusCode ?? 500;
        final data = error.response!.data;
        final message = data is Map ? (data['detail'] ?? 'Unknown error') : 'Server error';
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: ApiException(statusCode: statusCode, message: message.toString()),
          type: DioExceptionType.badResponse,
          response: error.response,
        ));
      } else {
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: NetworkException('Connection failed'),
          type: DioExceptionType.connectionError,
        ));
      }
    },
  ));

  return dio;
});

/// Attempt to refresh the access token using the current (possibly near-expiry) token.
Future<bool> _attemptTokenRefresh(Dio dio) async {
  try {
    final currentToken = await _storage.read(key: 'access_token');
    if (currentToken == null) return false;

    final response = await Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $currentToken',
      },
    )).post('/auth/refresh');

    if (response.statusCode == 200 && response.data['access_token'] != null) {
      await _storage.write(key: 'access_token', value: response.data['access_token']);
      if (response.data['role'] != null) {
        await _storage.write(key: 'user_role', value: response.data['role']);
      }
      return true;
    }
  } catch (_) {
    // Token is fully expired or invalid — user must re-login
  }
  return false;
}

final storageProvider = Provider<FlutterSecureStorage>((ref) => _storage);
