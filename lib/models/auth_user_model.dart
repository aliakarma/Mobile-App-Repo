class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
  });

  final int id;
  final String fullName;
  final String email;
  final DateTime createdAt;

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] ?? json['createdAt'];
    return AuthUserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: (json['full_name'] ?? json['fullName'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      createdAt: DateTime.tryParse(createdAtRaw?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
