import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/notifications/presentation/providers/notifications_provider.dart';
import '../../../features/notifications/domain/entities/app_notification.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              tooltip: 'Marcar todas como leídas',
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                ref.read(notificationsProvider.notifier).clearAll();
              },
              tooltip: 'Limpiar todas',
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No hay notificaciones',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las notificaciones aparecerán aquí',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    ref.read(notificationsProvider.notifier).removeNotification(notification.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notificación eliminada')),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: notification.isRead ? Colors.white : Colors.blue.shade50,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getNotificationColor(notification.type).withValues(alpha: 0.2),
                        child: Icon(
                          _getNotificationIcon(notification.type),
                          color: _getNotificationColor(notification.type),
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(notification.body),
                          const SizedBox(height: 4),
                          Text(
                            _getTimeAgo(notification.timestamp),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: notification.isRead
                          ? null
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                      onTap: () {
                        if (!notification.isRead) {
                          ref.read(notificationsProvider.notifier).markAsRead(notification.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.zoneEntry:
        return Icons.login;
      case NotificationType.zoneExit:
        return Icons.logout;
      case NotificationType.lowBattery:
        return Icons.battery_alert;
      case NotificationType.alert:
        return Icons.warning;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.zoneEntry:
        return Colors.green;
      case NotificationType.zoneExit:
        return Colors.orange;
      case NotificationType.lowBattery:
        return Colors.red;
      case NotificationType.alert:
        return Colors.red;
      case NotificationType.general:
        return AppColors.primary;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inSeconds < 60) {
      return 'Hace ${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else {
      return 'Hace ${difference.inDays}d';
    }
  }
}
