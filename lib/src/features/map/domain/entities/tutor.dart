class Tutor {
  final String id;
  final String name;
  final String email;
  final String type;

  Tutor({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
  });

  factory Tutor.fromJson(Map<String, dynamic> json) {
    return Tutor(
      id: json['id'].toString(),
      name: json['nombre'] ?? '',
      email: json['email'] ?? '',
      type: json['tipo'] ?? '',
    );
  }
}
