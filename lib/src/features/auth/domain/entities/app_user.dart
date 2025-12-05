class AppUser {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final String role; // 'tutor' or 'hijo'
  final List<String> childrenIds;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    this.role = 'tutor', // Default to tutor
    this.childrenIds = const [],
  });

  factory AppUser.fromFirebase(dynamic firebaseUser) {
    return AppUser(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? 'Usuario',
      photoUrl: firebaseUser.photoURL,
      role: 'tutor', // Firebase auth usually implies tutor/parent in this context initially
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      email: json['email'] as String,
      name: json['nombre'] as String,
      photoUrl: null,
      role: json['tipo'] as String? ?? 'tutor', // Map 'tipo' from backend to 'role'
    );
  }
}
