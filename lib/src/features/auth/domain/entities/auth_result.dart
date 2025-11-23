import 'app_user.dart';

class AuthResult {
  final String accessToken;
  final AppUser user;

  AuthResult({
    required this.accessToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
