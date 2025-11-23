class Child {
  final String id;
  final String name;
  final int age;
  final String emoji;
  final String phone;
  final String device;
  final String status; // 'online' | 'offline'
  final double battery;
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;

  Child({
    required this.id,
    required this.name,
    required this.age,
    required this.emoji,
    required this.phone,
    required this.device,
    required this.status,
    required this.battery,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
  });

  // Factory for creating from JSON (useful later for API)
  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'],
      name: json['name'],
      age: json['age'],
      emoji: json['emoji'],
      phone: json['phone'],
      device: json['device'],
      status: json['status'],
      battery: (json['battery'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}
