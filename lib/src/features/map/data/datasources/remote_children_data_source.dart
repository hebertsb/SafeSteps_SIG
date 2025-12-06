import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../domain/entities/child.dart';

abstract class RemoteChildrenDataSource {
  Future<List<Child>> getChildren();
  Future<Child> createChild({
    required String name,
    required String email,
    required String password,
    double? latitude,
    double? longitude,
  });
  Future<Child> getChildById(String id);
  Future<void> deleteChild(String id);
  Future<Child> updateChild(String id, Map<String, dynamic> data);
  Future<Child> updateChildLocation(String id, double latitude, double longitude);
  Future<void> removeChildFromTutor(String tutorId, String childId);
}

class RemoteChildrenDataSourceImpl implements RemoteChildrenDataSource {
<<<<<<< HEAD
  // Backend URL - Tu PC WiFi IP
  // Para dispositivo físico o iOS simulator: usa 192.168.0.8:3000
  static const _baseUrl = 'http://192.168.0.8:3000';
=======
  // Use env var or fallback to localhost
  static String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000'; 
>>>>>>> 39a4014fdb5c1b44b0732d23ca75cbc1b91bb01e
  
  final http.Client client;

  RemoteChildrenDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  Future<String?> _getToken() async {
    return await SecureStorageService.instance.read(key: SecureStorageService.tokenKey);
  }

  @override
  Future<List<Child>> getChildren() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/hijos');
    
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
        return jsonList.map((json) => Child.fromJson(json)).toList();
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
        headers: {
          'Authorization': 'Bearer $token',
        },
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
  Future<Child> updateChildLocation(String id, double latitude, double longitude) async {
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
        body: jsonEncode({
          'latitud': latitude,
          'longitud': longitude,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Child.fromJson(json);
      } else {
        throw Exception('Failed to update child location: ${response.statusCode}');
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
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove child from tutor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error removing child from tutor: $e');
    }
  }

  @override
  Future<Child> createChild({
    required String name,
    required String email,
    required String password,
    double? latitude,
    double? longitude,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    // Updated endpoint to associate child with logged-in tutor automatically
    final uri = Uri.parse('$_baseUrl/tutores/me/hijos');
    
    try {
      final response = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombre': name,
          'email': email,
          'password': password,
          // Latitude and longitude might not be supported by this specific endpoint based on docs,
          // but sending them just in case or we can update location later.
          // The docs say it receives nombre, email, password.
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Child.fromJson(json);
      } else {
        final Map<String, dynamic> error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create child');
      }
    } catch (e) {
      throw Exception('Error creating child: $e');
    }
  }
}
