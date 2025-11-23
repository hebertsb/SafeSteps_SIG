import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../../../core/services/secure_storage_service.dart';

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Auth Controller Provider (Manages Auth State)
final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    return _checkAuthState();
  }

  Future<AppUser?> _checkAuthState() async {
    try {
      // Check for stored token
      final token = await SecureStorageService.instance.read(key: SecureStorageService.tokenKey);
      
      if (token != null) {
        // TODO: Validate token with backend or decode JWT to get user info
        // For now, we'll assume if token exists, user is logged in.
        // Ideally, we should fetch user profile from backend here.
        // Creating a dummy user for now to unblock navigation
        return AppUser(id: 'backend_user', email: 'user@backend.com', name: 'User');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _syncFcmToken(String jwtToken) async {
    try {
      print('========== SYNCING FCM TOKEN ==========');
      print('JWT Token (first 20 chars): ${jwtToken.substring(0, jwtToken.length > 20 ? 20 : jwtToken.length)}...');
      
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token obtenido: $fcmToken');
      
      if (fcmToken == null) {
        print('⚠️ FCM Token es null - No se puede sincronizar');
        return;
      }
      
      print('Enviando FCM Token al backend...');
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.updateFcmToken(fcmToken, jwtToken);
      print('✅ FCM Token synced with backend: $fcmToken');
    } catch (e) {
      print('❌ Error syncing FCM token: $e');
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final result = await authRepository.loginWithBackend(email: email, password: password);
      
      await SecureStorageService.instance.write(
        key: SecureStorageService.tokenKey,
        value: result.accessToken,
      );

      // Sync FCM Token
      await _syncFcmToken(result.accessToken);

      return result.user;
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String type,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final result = await authRepository.registerWithBackend(
        name: name,
        email: email,
        password: password,
        type: type,
      );
      
      await SecureStorageService.instance.write(
        key: SecureStorageService.tokenKey,
        value: result.accessToken,
      );

      // Sync FCM Token
      await _syncFcmToken(result.accessToken);

      return result.user;
    });
  }

  Future<void> logout() async {
    await SecureStorageService.instance.delete(key: SecureStorageService.tokenKey);
    // Sign out from Firebase to prevent conflicts
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signOut();
    state = const AsyncValue.data(null);
  }
}

// Legacy providers for compatibility (if needed, but better to migrate)
final authStateProvider = Provider<AsyncValue<AppUser?>>((ref) {
  return ref.watch(authControllerProvider);
});

// Current User Provider
final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});
