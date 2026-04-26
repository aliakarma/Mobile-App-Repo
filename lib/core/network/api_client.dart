import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../error/app_exception.dart';

typedef UnauthorizedInterceptor = FutureOr<void> Function();

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.getRetryCount = 2,
    this.onUnauthorized,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
  final Duration timeout;
  final int getRetryCount;
  final UnauthorizedInterceptor? onUnauthorized;

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration? timeoutOverride,
  }) async {
    final response = await _send(
      method: 'POST',
      path: path,
      body: body,
      headers: headers,
      timeoutOverride: timeoutOverride,
    );

    return _decodeJsonMap(response.body);
  }

  Future<Map<String, dynamic>> getJsonMap(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      method: 'GET',
      path: path,
      headers: headers,
      enableRetry: true,
    );

    return _decodeJsonMap(response.body);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      method: 'GET',
      path: path,
      headers: headers,
      enableRetry: true,
    );

    final decoded = _decodeJson(response.body);
    if (decoded is List<dynamic>) {
      return decoded;
    }

    throw const BackendException(
      userMessage: 'The server returned an invalid response format.',
      retryable: false,
    );
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool enableRetry = false,
    Duration? timeoutOverride,
  }) async {
    final attempts = enableRetry ? getRetryCount + 1 : 1;
    var attempt = 0;
    AppException? lastError;

    while (attempt < attempts) {
      attempt++;

      try {
        return await _sendOnce(
          method: method,
          path: path,
          body: body,
          headers: headers,
          timeoutOverride: timeoutOverride,
        );
      } on AppException catch (error) {
        lastError = error;
        if (!_shouldRetry(
            error: error,
            method: method,
            attempt: attempt,
            attempts: attempts)) {
          rethrow;
        }
      }
    }

    throw lastError ?? const NetworkException();
  }

  bool _shouldRetry({
    required AppException error,
    required String method,
    required int attempt,
    required int attempts,
  }) {
    if (method != 'GET') {
      return false;
    }

    if (attempt >= attempts) {
      return false;
    }

    return error.retryable;
  }

  Future<http.Response> _sendOnce({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeoutOverride,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final requestTimeout = timeoutOverride ?? timeout;

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response =
              await _httpClient.get(uri, headers: headers).timeout(requestTimeout);
          break;
        case 'POST':
          response = await _httpClient
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  ...?headers,
                },
                body: jsonEncode(body ?? const <String, dynamic>{}),
              )
              .timeout(requestTimeout);
          break;
        default:
          throw BackendException(
            userMessage: 'Unsupported HTTP method: $method',
            retryable: false,
          );
      }
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException(
        userMessage: 'The request timed out. Please try again.',
      );
    }

    final payload = decodeJsonMapOrEmpty(response.body);

    if (response.statusCode == 401 && onUnauthorized != null) {
      try {
        await onUnauthorized!.call();
      } catch (_) {
        // Swallow interceptor errors to avoid masking the auth failure.
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw mapApiException(statusCode: response.statusCode, payload: payload);
    }

    return response;
  }

  dynamic _decodeJson(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      throw const BackendException(
        userMessage: 'The server returned an invalid response format.',
        retryable: false,
      );
    }
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final decoded = _decodeJson(body);
    if (decoded == null) {
      return const <String, dynamic>{};
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const BackendException(
      userMessage: 'The server returned an invalid response format.',
      retryable: false,
    );
  }

  Map<String, dynamic> decodeJsonMapOrEmpty(String body) {
    if (body.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Handled below.
    }

    throw const BackendException(
      userMessage: 'The server returned an invalid response format.',
      retryable: false,
    );
  }
}
