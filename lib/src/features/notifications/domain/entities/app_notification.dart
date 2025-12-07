class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool isRead;
  final bool isLocal;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.data = const {},
    this.isRead = false,
    this.isLocal = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    bool? isLocal,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      isLocal: isLocal ?? this.isLocal,
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
      isLocal: false,
      data: json,
    );
  }

  static String _getTitleFromType(String type) {
    switch (type) {
      case 'alert':
      case 'sos_panico':
        return 'Alerta de Seguridad';
      case 'zone_entry':
      case 'zona_segura':
        return '✅ Zona Segura';
      case 'zone_exit':
        return '⚠️ Salida de Zona';
      case 'low_battery':
        return 'Batería Baja';
      default:
        return 'Notificación';
    }
  }

  static NotificationType _getTypeFromString(String type) {
    switch (type) {
      case 'zone_entry':
      case 'zona_segura':
        return NotificationType.zoneEntry;
      case 'zone_exit':
        return NotificationType.zoneExit;
      case 'low_battery':
        return NotificationType.lowBattery;
      case 'alert':
      case 'sos_panico':
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
