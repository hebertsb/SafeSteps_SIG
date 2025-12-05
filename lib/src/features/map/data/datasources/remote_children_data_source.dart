import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/services/secure_storage_service.dart';
import '../../../auth/domain/entities/child.dart';

abstract class RemoteChildrenDataSource {
  Future<List<Child>> getChildren();
  Future<Child> createChild({
    required String name,
    required String email,
    required String password,
    double? latitude,
    double? longitude,
  });
}

class RemoteChildrenDataSourceImpl implements RemoteChildrenDataSource {
  // Use physical device IP - same as auth data source
  static const _baseUrl = 'http://192.168.1.14:3000'; 
  
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
  Future<Child> createChild({
    required String name,
    required String email,
    required String password,
    double? latitude,
    double? longitude,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/hijos');
    
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
          if (latitude != null) 'latitud': latitude,
          if (longitude != null) 'longitud': longitude,
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
