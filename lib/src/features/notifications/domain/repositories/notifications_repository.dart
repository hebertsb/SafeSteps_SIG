import '../entities/app_notification.dart';

abstract class NotificationsRepository {
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
