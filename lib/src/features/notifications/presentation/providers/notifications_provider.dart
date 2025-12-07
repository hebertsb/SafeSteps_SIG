import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/app_notification.dart';
import '../../data/services/fcm_service.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../data/datasources/remote_notifications_data_source.dart';
import '../../data/repositories/notifications_repository_impl.dart';

// Repository Provider
final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepositoryImpl(
    RemoteNotificationsDataSourceImpl(client: http.Client()),
  );
});

// FCM Service Provider
final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});

// Notifications State Provider using Riverpod 3.x Notifier
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  NotificationsRepository get _repository => ref.read(notificationsRepositoryProvider);

  @override
  List<AppNotification> build() {
    _fetchNotifications();
    return [];
  }

  Future<void> _fetchNotifications() async {
    try {
      final backendNotifications = await _repository.getNotifications();
      
      // Preserve local notifications that are not in the backend list
      final localNotifications = state.where((n) => n.isLocal).toList();
      
      // Merge: Local ones first (usually newer), then backend ones
      // Avoid duplicates if backend eventually returns the same event (unlikely if IDs differ)
      state = [...localNotifications, ...backendNotifications];
    } catch (e) {
      // Handle error silently or expose via another provider
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> refresh() async {
    await _fetchNotifications();
  }

  void addNotification(AppNotification notification) {
    state = [notification, ...state];
  }

  Future<void> markAsRead(String id) async {
    debugPrint('📬 markAsRead called for id: $id');
    
    final notificationIndex = state.indexWhere((n) => n.id == id);
    if (notificationIndex == -1) {
      debugPrint('❌ Notification not found: $id');
      return;
    }

    final notification = state[notificationIndex];
    debugPrint('📬 Notification found: isLocal=${notification.isLocal}, isRead=${notification.isRead}');
    
    // Optimistic update
    final updatedNotification = notification.copyWith(isRead: true);
    final newState = List<AppNotification>.from(state);
    newState[notificationIndex] = updatedNotification;
    state = newState;

    // Skip backend call only for truly local notifications (not from backend)
    if (notification.isLocal) {
      debugPrint('⏭️ Skipping backend call - local notification');
      return;
    }

    try {
      debugPrint('📤 Calling backend markAsRead for id: $id');
      await _repository.markAsRead([id]);
      debugPrint('✅ Backend markAsRead successful for id: $id');
      // Refresh unread count
      ref.refresh(unreadCountProvider);
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      // Revert optimistic update on error
      final revertedState = List<AppNotification>.from(state);
      revertedState[notificationIndex] = notification;
      state = revertedState;
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic update
    state = [
      for (final notification in state)
        notification.copyWith(isRead: true),
    ];

    try {
      await _repository.markAllAsRead();
      ref.refresh(unreadCountProvider);
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> clearAll() async {
    // Note: Backend doesn't support "delete all" without IDs, 
    // so we might need to delete visible ones or just clear local state.
    // For now, we'll just clear local state to reflect UI action, 
    // but ideally we should delete them from backend if that's the intent.
    // Or implement a loop to delete all.
    // Given the API, we'll just clear local for now or implement bulk delete of current list.
    try {
      final ids = state.map((n) => n.id).toList();
      if (ids.isNotEmpty) {
        await _repository.deleteNotifications(ids);
        state = [];
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  Future<void> removeNotification(String id) async {
    try {
      await _repository.deleteNotification(id);
      state = state.where((n) => n.id != id).toList();
    } catch (e) {
      debugPrint('Error removing notification: $e');
    }
  }
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(() {
  return NotificationsNotifier();
});

// Unread Count Provider
final unreadCountProvider = FutureProvider<int>((ref) async {
  // Option 1: Calculate from local state
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
  
  // Option 2: Fetch from backend (more accurate if pagination is used)
  // final repository = ref.read(notificationsRepositoryProvider);
  // return await repository.getUnreadCount();
});

// FCM Message Stream Provider
final fcmMessageStreamProvider = StreamProvider<RemoteMessage>((ref) {
  final fcmService = ref.watch(fcmServiceProvider);
  return fcmService.onMessage;
});

