import 'auth_user_model.dart';

class AuthSessionModel {
  const AuthSessionModel({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    required this.issuedAt,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final AuthUserModel user;
  final DateTime issuedAt;

  DateTime get expiresAt => issuedAt.add(Duration(seconds: expiresIn));
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  AuthSessionModel copyWith({
    String? accessToken,
    String? tokenType,
    int? expiresIn,
    AuthUserModel? user,
    DateTime? issuedAt,
  }) {
    return AuthSessionModel(
      accessToken: accessToken ?? this.accessToken,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
      user: user ?? this.user,
      issuedAt: issuedAt ?? this.issuedAt,
    );
  }

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final issuedAtRaw = json['issued_at'] ?? json['issuedAt'];
    return AuthSessionModel(
      accessToken: (json['access_token'] ?? json['accessToken'] as String? ?? '')
          .trim(),
      tokenType:
          (json['token_type'] ?? json['tokenType'] as String? ?? 'bearer')
              .trim(),
      expiresIn: (json['expires_in'] ?? json['expiresIn'] as num?)?.toInt() ??
          0,
      user: AuthUserModel.fromJson((json['user'] as Map?)?.cast<String, dynamic>() ?? const {}),
      issuedAt: DateTime.tryParse(issuedAtRaw?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'user': user.toJson(),
      'issued_at': issuedAt.toIso8601String(),
    };
  }
}
