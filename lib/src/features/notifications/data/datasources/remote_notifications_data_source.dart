import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/services/secure_storage_service.dart';
import '../../domain/entities/app_notification.dart';

abstract class RemoteNotificationsDataSource {
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
    String? type,
    bool? isRead,
  });
  Future<int> getUnreadCount();
  Future<void> markAllAsRead();
  Future<void> markAsRead(List<String> ids);
  Future<void> deleteNotification(String id);
  Future<void> deleteNotifications(List<String> ids);
  Future<AppNotification> sendNotification(String message, String type);
}

class RemoteNotificationsDataSourceImpl implements RemoteNotificationsDataSource {
  // Backend URL - Tu PC WiFi IP
  // Para dispositivo físico o iOS simulator: usa 192.168.0.8:3000
  static const _baseUrl = 'http://192.168.0.8:3000';
  
  final http.Client client;

  RemoteNotificationsDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  Future<String?> _getToken() async {
    return await SecureStorageService.instance.read(key: SecureStorageService.tokenKey);
  }

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
    String? type,
    bool? isRead,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (type != null) 'tipo': type,
      if (isRead != null) 'leida': isRead.toString(),
    };

    final uri = Uri.parse('$_baseUrl/notifications').replace(queryParameters: queryParams);
    
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
        return jsonList.map((json) => AppNotification.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  @override
  Future<int> getUnreadCount() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/notifications/unread/count');
    
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
        return json['count'] as int;
      } else {
        throw Exception('Failed to get unread count: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting unread count: $e');
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/notifications/mark-all-read');
    
    try {
      final response = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark all as read: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking all as read: $e');
    }
  }

  @override
  Future<void> markAsRead(List<String> ids) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/notifications/mark-read');
    
    try {
      final response = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'notificationIds': ids.map((id) => int.parse(id)).toList(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark as read: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking as read: $e');
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/notifications/$id');
    
    try {
      final response = await client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete notification: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting notification: $e');
    }
  }

  @override
  Future<void> deleteNotifications(List<String> ids) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/notifications');
    
    try {
      final response = await client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'notificationIds': ids.map((id) => int.parse(id)).toList(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete notifications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting notifications: $e');
    }
  }

  @override
  Future<AppNotification> sendNotification(String message, String type) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authenticated user');

    final uri = Uri.parse('$_baseUrl/notifications');
    
    try {
      final response = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'mensaje': message,
          'tipo': type,
        }),
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return AppNotification.fromJson(json);
      } else {
        throw Exception('Failed to send notification: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending notification: $e');
    }
  }
}
