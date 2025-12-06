import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/auth_result.dart';

abstract class RemoteAuthDataSource {
  Future<AuthResult> login({required String email, required String password});
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String type,
  });
  Future<void> updateFcmToken({required String token, required String jwtToken});
}

class RemoteAuthDataSourceImpl implements RemoteAuthDataSource {
  // Use env var or fallback to localhost
  static String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000';

  final http.Client client;

  RemoteAuthDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    
    try {
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        return AuthResult.fromJson(jsonBody);
      } else if (response.statusCode == 401) {
        final Map<String, dynamic> err = jsonDecode(response.body);
        throw AuthException(err['message'] ?? 'Credenciales inválidas');
      } else {
        throw AuthException(
            'Error inesperado (${response.statusCode}): ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error de conexión: $e');
    }
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String type,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/register');
    try {
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombre': name,
          'email': email,
          'password': password,
          'tipo': type,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        return AuthResult.fromJson(jsonBody);
      } else if (response.statusCode == 409) {
        throw AuthException('El correo ya está registrado');
      } else {
        final Map<String, dynamic> err = jsonDecode(response.body);
        throw AuthException(err['message'] ?? 'Error al registrar usuario');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error de conexión: $e');
    }
  }

  @override
  Future<void> updateFcmToken({required String token, required String jwtToken}) async {
    final uri = Uri.parse('$_baseUrl/users/fcm-token');
    
    try {
      final response = await client.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'fcmToken': token,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        // Handle error silently or log to crashlytics
      }
    } catch (e) {
      // Handle error silently
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
