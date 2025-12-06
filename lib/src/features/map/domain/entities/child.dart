import 'tutor.dart';

class Child {
  final String id;
  final String name;
  final String email;
  final int age;
  final String emoji;
  final String phone;
  final String device;
  final String status; // 'online' | 'offline'
  final double battery;
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;
  final List<Tutor> tutors;
  final String? codigoVinculacion; // Código de 6 caracteres para login

  Child({
    required this.id,
    required this.name,
    required this.email,
    this.age = 0,
    this.emoji = '👤',
    this.phone = '',
    this.device = 'Unknown',
    this.status = 'offline',
    this.battery = 0.0,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    this.tutors = const [],
    this.codigoVinculacion,
  });

  // Factory for creating from JSON (useful later for API)
  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'].toString(),
      name: json['nombre'] ?? json['name'] ?? 'Unknown',
      email: json['email'] ?? '',
      age: json['age'] ?? 0,
      emoji: json['emoji'] ?? '👤',
      phone: json['telefono']?.toString() ?? json['phone']?.toString() ?? '',
      device: json['device'] ?? 'Unknown',
      status: json['status'] ?? 'offline',
      battery: (json['battery'] as num?)?.toDouble() ?? 0.0,
      latitude:
          (json['latitud'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble() ??
          0.0,
      longitude:
          (json['longitud'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble() ??
          0.0,
      lastUpdated: json['ultimaconexion'] != null
          ? DateTime.parse(json['ultimaconexion'])
          : (json['lastUpdated'] != null
                ? DateTime.parse(json['lastUpdated'])
                : DateTime.now()),
      tutors:
          (json['tutores'] as List<dynamic>?)
              ?.map((t) => Tutor.fromJson(t))
              .toList() ??
          [],
      codigoVinculacion: json['codigoVinculacion'] as String?,
    );
  }

  Child copyWith({
    String? id,
    String? name,
    String? email,
    int? age,
    String? emoji,
    String? phone,
    String? device,
    String? status,
    double? battery,
    double? latitude,
    double? longitude,
    DateTime? lastUpdated,
  }) {
    return Child(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      emoji: emoji ?? this.emoji,
      phone: phone ?? this.phone,
      device: device ?? this.device,
      status: status ?? this.status,
      battery: battery ?? this.battery,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
