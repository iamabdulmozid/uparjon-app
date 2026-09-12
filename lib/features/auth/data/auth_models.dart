/// The signed-in user (API: `UserSummaryDTO`).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    this.email,
    this.profileImage,
    this.role,
    this.roles = const [],
    this.mustChangePassword = false,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? profileImage;
  final String? role;
  final List<String> roles;
  final bool mustChangePassword;

  /// First name only — the home header greets with `Hi, <name>`.
  String get shortName => fullName.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'profileImage': profileImage,
    'role': role,
    'roles': roles,
    'mustChangePassword': mustChangePassword,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id']?.toString() ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String?,
    profileImage: json['profileImage'] as String?,
    role: json['role'] as String?,
    roles:
        (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    mustChangePassword: json['mustChangePassword'] as bool? ?? false,
  );
}

/// A successful login/registration (API: `AuthResponse`).
class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  /// Access-token lifetime in seconds (900 = 15 minutes).
  final int? expiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    user: AuthUser.fromJson(
      (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    accessToken: json['accessToken'] as String? ?? '',
    refreshToken: json['refreshToken'] as String? ?? '',
    expiresIn: (json['expiresIn'] as num?)?.toInt(),
  );
}
