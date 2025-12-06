class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.data = const {},
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: _getTitleFromType(json['tipo'] ?? 'info'),
      body: json['mensaje'] ?? '',
      timestamp: DateTime.parse(json['createdAt']),
      type: _getTypeFromString(json['tipo'] ?? 'info'),
      isRead: json['leida'] ?? false,
      data: json,
    );
  }

  static String _getTitleFromType(String type) {
    switch (type) {
      case 'alert':
        return 'Alerta de Seguridad';
      case 'zone_entry':
        return 'Entrada a Zona';
      case 'zone_exit':
        return 'Salida de Zona';
      case 'low_battery':
        return 'Batería Baja';
      default:
        return 'Notificación';
    }
  }

  static NotificationType _getTypeFromString(String type) {
    switch (type) {
      case 'zone_entry':
        return NotificationType.zoneEntry;
      case 'zone_exit':
        return NotificationType.zoneExit;
      case 'low_battery':
        return NotificationType.lowBattery;
      case 'alert':
        return NotificationType.alert;
      default:
        return NotificationType.general;
    }
  }
}

enum NotificationType {
  zoneEntry,
  zoneExit,
  lowBattery,
  alert,
  general,
}
