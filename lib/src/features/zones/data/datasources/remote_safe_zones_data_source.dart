import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../domain/entities/safe_zone.dart';

abstract class RemoteSafeZonesDataSource {
  Future<List<SafeZone>> getSafeZones();
  Future<SafeZone> getSafeZoneById(String id);
  Future<SafeZone> createSafeZone({
    required String name,
    required String description,
    required List<List<double>> points,
    required List<int> childrenIds,
  });
  Future<void> deleteSafeZone(String id);
  Future<SafeZone> updateSafeZone(String id, Map<String, dynamic> data);
}

class RemoteSafeZonesDataSourceImpl implements RemoteSafeZonesDataSource {
  // Use env var or fallback to localhost
  static String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000'; 
  
  final http.Client client;

  RemoteSafeZonesDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  Future<String?> _getToken() async {
    return await SecureStorageService.instance.read(key: SecureStorageService.tokenKey);
  }

  @override
  Future<List<SafeZone>> getSafeZones() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/zonas-seguras');
    
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
        return jsonList.map((json) => SafeZone.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load safe zones: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching safe zones: $e');
    }
  }

  @override
  Future<SafeZone> getSafeZoneById(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/zonas-seguras/$id');
    
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
        return SafeZone.fromJson(json);
      } else {
        throw Exception('Failed to load safe zone: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching safe zone: $e');
    }
  }

  @override
  Future<SafeZone> createSafeZone({
    required String name,
    required String description,
    required List<List<double>> points,
    required List<int> childrenIds,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/zonas-seguras');
    
    // Construct GeoJSON Polygon
    // Ensure the polygon is closed (first point = last point)
    final List<List<double>> closedPoints = List.from(points);
    if (points.isNotEmpty && points.first != points.last) {
      closedPoints.add(points.first);
    }

    final Map<String, dynamic> polygonGeoJSON = {
      "type": "Polygon",
      "coordinates": [closedPoints]
    };

    try {
      final response = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombre': name,
          'descripcion': description,
          'poligono': polygonGeoJSON,
          'hijosIds': childrenIds,
        }),
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return SafeZone.fromJson(json);
      } else {
        throw Exception('Failed to create safe zone: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating safe zone: $e');
    }
  }

  @override
  Future<void> deleteSafeZone(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/zonas-seguras/$id');
    
    try {
      final response = await client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete safe zone: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting safe zone: $e');
    }
  }

  @override
  Future<SafeZone> updateSafeZone(String id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/zonas-seguras/$id');
    
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
        return SafeZone.fromJson(json);
      } else {
        throw Exception('Failed to update safe zone: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating safe zone: $e');
    }
  }
}
