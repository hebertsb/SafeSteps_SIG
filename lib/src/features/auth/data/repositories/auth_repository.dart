import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_result.dart';
import '../datasources/remote_auth_data_source.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  AppUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return AppUser.fromFirebase(user);
  }

  // Stream of auth state changes
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) return null;
      return AppUser.fromFirebase(user);
    });
  }

  // Sign in with email and password
  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AppUser.fromFirebase(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<AppUser?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user!.updateDisplayName(name);
      await credential.user!.reload();

      return AppUser.fromFirebase(_firebaseAuth.currentUser!);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<AppUser?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      return AppUser.fromFirebase(userCredential.user!);
    } catch (e) {
      throw 'Error al iniciar sesión con Google';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Backend Login
  Future<AuthResult> loginWithBackend({
    required String email,
    required String password,
  }) async {
    final remoteDataSource = RemoteAuthDataSourceImpl();
    return await remoteDataSource.login(email: email, password: password);
  }

  // Backend Login with Code (for children)
  Future<AuthResult> loginWithCode({required String code}) async {
    final remoteDataSource = RemoteAuthDataSourceImpl();
    return await remoteDataSource.loginWithCode(code: code);
  }

  // Backend Register
  Future<AuthResult> registerWithBackend({
    required String name,
    required String email,
    required String password,
    required String type,
  }) async {
    final remoteDataSource = RemoteAuthDataSourceImpl();
    return await remoteDataSource.register(
      name: name,
      email: email,
      password: password,
      type: type,
    );
  }

  // Update FCM Token
  Future<void> updateFcmToken(String token, String jwtToken) async {
    final remoteDataSource = RemoteAuthDataSourceImpl();
    await remoteDataSource.updateFcmToken(token: token, jwtToken: jwtToken);
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Este correo ya está registrado';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      default:
        return 'Error de autenticación: ${e.message}';
    }
  }
}
