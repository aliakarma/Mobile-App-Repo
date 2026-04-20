import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  AuthApiService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;

  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8001';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8001';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8001';
    }
  }

  Future<AuthSessionModel> signUp({
    required String fullName,
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _post(
      '/auth/signup',
      body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'remember_me': rememberMe,
      },
    );

    final payload = _decodeJsonMap(response.body);
    _ensureSuccess(response, payload);
    return AuthSessionModel.fromJson(payload)
        .copyWith(issuedAt: DateTime.now());
  }

  Future<AuthSessionModel> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        'remember_me': rememberMe,
      },
    );

    final payload = _decodeJsonMap(response.body);
    _ensureSuccess(response, payload);
    return AuthSessionModel.fromJson(payload)
        .copyWith(issuedAt: DateTime.now());
  }

  Future<AuthUserModel> fetchCurrentUser(String accessToken) async {
    final response = await _get(
      '/auth/me',
      headers: _authHeaders(accessToken),
    );

    final payload = _decodeJsonMap(response.body);
    _ensureSuccess(response, payload);
    return AuthUserModel.fromJson(payload);
  }

  Future<void> logout(String accessToken) async {
    final response = await _post(
      '/auth/logout',
      body: const {},
      headers: _authHeaders(accessToken),
    );

    final payload = _decodeJsonMap(response.body);
    _ensureSuccess(response, payload);
  }

  Future<http.Response> _post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      return await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: jsonEncode(body),
      );
    } on SocketException {
      throw const AuthApiException(
        message:
            'Unable to reach backend. Please verify the server is running and reachable.',
      );
    }
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      return await http.get(uri, headers: headers);
    } on SocketException {
      throw const AuthApiException(
        message:
            'Unable to reach backend. Please verify the server is running and reachable.',
      );
    }
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {'Authorization': 'Bearer $accessToken'};
  }

  void _ensureSuccess(http.Response response, Map<String, dynamic> payload) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final detail = payload['detail']?.toString();
    final error = payload['error']?.toString();
    final message =
        detail ?? error ?? 'Request failed with ${response.statusCode}.';
    throw AuthApiException(
      message: message,
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    if (body.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const AuthApiException(
        message: 'Invalid response format from backend.');
  }
}
