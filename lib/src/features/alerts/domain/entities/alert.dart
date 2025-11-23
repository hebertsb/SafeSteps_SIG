class Alert {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;
  final String type; // 'zone_enter', 'zone_exit', 'battery', 'sos'

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.read,
    required this.type,
  });
}
