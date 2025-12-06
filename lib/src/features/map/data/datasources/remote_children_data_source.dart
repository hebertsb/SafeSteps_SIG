import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../domain/entities/child.dart';

abstract class RemoteChildrenDataSource {
  Future<List<Child>> getChildren();
  Future<Child> createChild({
    required String name,
    String? lastName,
    String? phone,
  });
  Future<Child> getChildById(String id);
  Future<void> deleteChild(String id);
  Future<Child> updateChild(String id, Map<String, dynamic> data);
  Future<Child> updateChildLocation(
    String id,
    double latitude,
    double longitude,
  );
  Future<void> removeChildFromTutor(String tutorId, String childId);
  Future<String> regenerateCode(String childId);
}

class RemoteChildrenDataSourceImpl implements RemoteChildrenDataSource {
  // Use env var or fallback to localhost
  static String get _baseUrl =>
      dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000';

  final http.Client client;

  RemoteChildrenDataSourceImpl({http.Client? client})
    : client = client ?? http.Client();

  Future<String?> _getToken() async {
    return await SecureStorageService.instance.read(
      key: SecureStorageService.tokenKey,
    );
  }

  @override
  Future<List<Child>> getChildren() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    // Usar el endpoint que devuelve SOLO los hijos del tutor autenticado
    final uri = Uri.parse('$_baseUrl/tutores/me/hijos');

    try {
      final response = await client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        // Filtrar solo hijos con ubicación válida (lat y lng != 0)
        return jsonList
            .map((json) => Child.fromJson(json))
            .where((child) => child.latitude != 0 || child.longitude != 0)
            .toList();
      } else {
        throw Exception('Failed to load children: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching children: $e');
    }
  }

  @override
  Future<Child> getChildById(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/hijos/$id');

    try {
      final response = await client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Child.fromJson(json);
      } else {
        throw Exception('Failed to load child: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching child: $e');
    }
  }

  @override
  Future<void> deleteChild(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/hijos/$id');

    try {
      final response = await client.delete(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete child: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting child: $e');
    }
  }

  @override
  Future<Child> updateChild(String id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/hijos/$id');

    try {
      final response = await client.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Child.fromJson(json);
      } else {
        throw Exception('Failed to update child: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating child: $e');
    }
  }

  @override
  Future<Child> updateChildLocation(
    String id,
    double latitude,
    double longitude,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/hijos/$id/location');

    try {
      final response = await client.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'latitud': latitude, 'longitud': longitude}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Child.fromJson(json);
      } else {
        throw Exception(
          'Failed to update child location: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error updating child location: $e');
    }
  }

  @override
  Future<void> removeChildFromTutor(String tutorId, String childId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/tutores/$tutorId/hijos/$childId');

    try {
      final response = await client.delete(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to remove child from tutor: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error removing child from tutor: $e');
    }
  }

  @override
  Future<Child> createChild({
    required String name,
    String? lastName,
    String? phone,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    // Endpoint según documentación del backend v2.0
    // Backend genera automáticamente email y password
    final uri = Uri.parse('$_baseUrl/tutores/registrar-hijo');

    try {
      final response = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombre': name,
          if (lastName != null && lastName.isNotEmpty) 'apellido': lastName,
          if (phone != null && phone.isNotEmpty) 'telefono': phone,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Child.fromJson(json);
      } else if (response.statusCode == 409) {
        throw Exception('El email ya está registrado');
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> error = jsonDecode(response.body);
        final message = error['message'];
        if (message is List) {
          throw Exception(message.first);
        }
        throw Exception(message ?? 'Datos inválidos');
      } else {
        final Map<String, dynamic> error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Error al registrar hijo');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<String> regenerateCode(String childId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    // Endpoint según API-REGENERAR-CODIGO-HIJO.md
    final uri = Uri.parse('$_baseUrl/hijos/$childId/regenerar-codigo');

    try {
      final response = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}), // Body vacío según la guía
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return json['codigoVinculacion'] as String;
      } else if (response.statusCode == 401) {
        throw Exception(
          'No tienes permisos para regenerar el código de este hijo',
        );
      } else if (response.statusCode == 404) {
        throw Exception('Hijo no encontrado');
      } else {
        final Map<String, dynamic> error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Error al regenerar código');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Error de conexión: $e');
    }
  }
}
