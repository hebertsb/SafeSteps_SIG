import 'dart:developer';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/auth_result.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  // Use physical device IP
  String get _baseUrl => dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:3000';

  final http.Client client;

  RemoteAuthDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    print('Attempting login to: $uri');
    print('Email: $email');
    
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

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

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
      print('Login error: $e');
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
    print('========== UPDATE FCM TOKEN REQUEST ==========');
    print('URL: $uri');
    print('FCM Token: $token');
    print('JWT Token (first 20 chars): ${jwtToken.substring(0, jwtToken.length > 20 ? 20 : jwtToken.length)}...');
    
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

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ FCM Token enviado correctamente');
      } else {
        print('❌ Error enviando FCM Token: ${response.body}');
      }
    } catch (e) {
      print('❌ Error en updateFcmToken: $e');
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
