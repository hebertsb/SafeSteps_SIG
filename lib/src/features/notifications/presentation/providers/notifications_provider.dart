import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../domain/entities/app_notification.dart';
import '../../data/services/fcm_service.dart';

// FCM Service Provider
final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});

// Notifications State Provider using Riverpod 3.x Notifier
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    return [];
  }

  void addNotification(AppNotification notification) {
    state = [notification, ...state];
  }

  void markAsRead(String id) {
    state = [
      for (final notification in state)
        if (notification.id == id)
          notification.copyWith(isRead: true)
        else
          notification,
    ];
  }

  void markAllAsRead() {
    state = [
      for (final notification in state)
        notification.copyWith(isRead: true),
    ];
  }

  void clearAll() {
    state = [];
  }

  void removeNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(() {
  return NotificationsNotifier();
});

// Unread Count Provider
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

// FCM Message Stream Provider
final fcmMessageStreamProvider = StreamProvider<RemoteMessage>((ref) {
  final fcmService = ref.watch(fcmServiceProvider);
  return fcmService.onMessage;
});
