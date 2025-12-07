import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

class RemoteNotificationsDataSourceImpl
    implements RemoteNotificationsDataSource {
  // Use env var or fallback to localhost
  static String get _baseUrl =>
      dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000';

  final http.Client client;

  RemoteNotificationsDataSourceImpl({http.Client? client})
    : client = client ?? http.Client();

  Future<String?> _getToken() async {
    return await SecureStorageService.instance.read(
      key: SecureStorageService.tokenKey,
    );
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

    final uri = Uri.parse(
      '$_baseUrl/notifications',
    ).replace(queryParameters: queryParams);

    try {
      print('🔍 Fetching notifications from: $uri');
      final response = await client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 Response status: ${response.statusCode}');
      print('🔍 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decodedJson = jsonDecode(response.body);
        
        List<dynamic> jsonList = [];

        if (decodedJson is Map<String, dynamic>) {
          if (decodedJson.containsKey('notifications') && decodedJson['notifications'] is List) {
            jsonList = decodedJson['notifications'];
          } else if (decodedJson.containsKey('data') && decodedJson['data'] is List) {
             jsonList = decodedJson['data'];
          } else {
             // Fallback or empty
             print('⚠️ Could not find notifications list in response');
          }
        } else if (decodedJson is List) {
          jsonList = decodedJson;
        }

        return jsonList.map((json) {
          try {
            return AppNotification.fromJson(json);
          } catch (e) {
            print('❌ Error parsing notification item: $e');
            return null; 
          }
        }).whereType<AppNotification>().toList(); // Filter out nulls
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
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
        headers: {'Authorization': 'Bearer $token'},
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
          'notificationIds': ids.map((id) => int.tryParse(id) ?? id).toList(),
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
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 204) {
        throw Exception(
          'Failed to delete notification: ${response.statusCode}',
        );
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
        throw Exception(
          'Failed to delete notifications: ${response.statusCode}',
        );
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
        body: jsonEncode({'mensaje': message, 'tipo': type}),
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
