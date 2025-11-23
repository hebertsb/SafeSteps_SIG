class AppUser {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final List<String> childrenIds;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    this.childrenIds = const [],
  });

  factory AppUser.fromFirebase(dynamic firebaseUser) {
    return AppUser(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? 'Usuario',
      photoUrl: firebaseUser.photoURL,
    );
  }
}
