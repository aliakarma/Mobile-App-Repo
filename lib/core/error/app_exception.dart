class AppException implements Exception {
  const AppException({
    required this.userMessage,
    this.statusCode,
    this.retryable = false,
  });

  final String userMessage;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => userMessage;
}

class NetworkException extends AppException {
  const NetworkException({
    super.userMessage =
        'Unable to reach the server. Check your connection and try again.',
    super.retryable = true,
  });
}

class AuthException extends AppException {
  const AuthException({
    required super.userMessage,
    super.statusCode,
    super.retryable,
  });
}

class QuotaException extends AppException {
  const QuotaException({
    required super.userMessage,
    super.statusCode,
    super.retryable,
  });
}

class BackendException extends AppException {
  const BackendException({
    required super.userMessage,
    super.statusCode,
    super.retryable,
  });
}

AppException mapApiException({
  required int statusCode,
  required Map<String, dynamic> payload,
}) {
  final userMessage = _extractUserMessage(payload, statusCode);
  final retryable = payload['retryable'] == true;

  if (statusCode == 401 || statusCode == 403) {
    return AuthException(
      userMessage: userMessage,
      statusCode: statusCode,
      retryable: false,
    );
  }

  if (statusCode == 429) {
    return QuotaException(
      userMessage: userMessage,
      statusCode: statusCode,
      retryable: true,
    );
  }

  return BackendException(
    userMessage: userMessage,
    statusCode: statusCode,
    retryable: retryable || statusCode >= 500,
  );
}

String _extractUserMessage(Map<String, dynamic> payload, int statusCode) {
  final userMessage = payload['user_message']?.toString().trim();
  if (userMessage != null && userMessage.isNotEmpty) {
    return userMessage;
  }

  final detail = payload['detail']?.toString().trim();
  if (detail != null && detail.isNotEmpty) {
    return detail;
  }

  if (statusCode >= 500) {
    return 'The server is currently unavailable. Please try again.';
  }

  return 'Request failed with status $statusCode.';
}
