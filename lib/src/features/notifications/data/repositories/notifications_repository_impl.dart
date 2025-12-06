import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/remote_notifications_data_source.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final RemoteNotificationsDataSource _dataSource;

  NotificationsRepositoryImpl(this._dataSource);

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
    String? type,
    bool? isRead,
  }) async {
    return await _dataSource.getNotifications(
      limit: limit,
      offset: offset,
      type: type,
      isRead: isRead,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    return await _dataSource.getUnreadCount();
  }

  @override
  Future<void> markAllAsRead() async {
    await _dataSource.markAllAsRead();
  }

  @override
  Future<void> markAsRead(List<String> ids) async {
    await _dataSource.markAsRead(ids);
  }

  @override
  Future<void> deleteNotification(String id) async {
    await _dataSource.deleteNotification(id);
  }

  @override
  Future<void> deleteNotifications(List<String> ids) async {
    await _dataSource.deleteNotifications(ids);
  }

  @override
  Future<AppNotification> sendNotification(String message, String type) async {
    return await _dataSource.sendNotification(message, type);
  }
}
