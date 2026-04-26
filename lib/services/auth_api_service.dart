import '../core/config/app_config.dart';
import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';

import '../models/auth_session_model.dart';
import '../models/auth_user_model.dart';

class AuthApiException implements Exception {
  const AuthApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthApiService {
  AuthApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<AuthSessionModel> signUp({
    required String fullName,
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final payload = await _runGuarded(
      () => _apiClient.postJson(
        '/auth/signup',
        body: {
          'full_name': fullName,
          'email': email,
          'password': password,
          'remember_me': rememberMe,
        },
      ),
    );

    return AuthSessionModel.fromJson(payload)
        .copyWith(issuedAt: DateTime.now());
  }

  Future<AuthSessionModel> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final payload = await _runGuarded(
      () => _apiClient.postJson(
        '/auth/login',
        body: {
          'email': email,
          'password': password,
          'remember_me': rememberMe,
        },
      ),
    );

    return AuthSessionModel.fromJson(payload)
        .copyWith(issuedAt: DateTime.now());
  }

  Future<AuthUserModel> fetchCurrentUser(String accessToken) async {
    final payload = await _runGuarded(
      () => _apiClient.getJsonMap(
        '/auth/me',
        headers: _authHeaders(accessToken),
      ),
    );

    return AuthUserModel.fromJson(payload);
  }

  Future<void> logout(String accessToken) async {
    await _runGuarded(
      () => _apiClient.postJson(
        '/auth/logout',
        body: const {},
        headers: _authHeaders(accessToken),
      ),
    );
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {'Authorization': 'Bearer $accessToken'};
  }

  Future<Map<String, dynamic>> _runGuarded(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      return await action();
    } on AppException catch (error) {
      throw AuthApiException(
        message: error.userMessage,
        statusCode: error.statusCode,
      );
    }
  }
}
