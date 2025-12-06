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
final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    return _checkAuthState();
  }

  Future<AppUser?> _checkAuthState() async {
    try {
      // Check for stored token
      final token = await SecureStorageService.instance.read(
        key: SecureStorageService.tokenKey,
      );

      if (token != null) {
        final userId = await SecureStorageService.instance.read(
          key: SecureStorageService.userIdKey,
        );
        final userName = await SecureStorageService.instance.read(
          key: SecureStorageService.userNameKey,
        );
        final userEmail = await SecureStorageService.instance.read(
          key: SecureStorageService.userEmailKey,
        );
        final userType = await SecureStorageService.instance.read(
          key: SecureStorageService.userTypeKey,
        );

        if (userId != null && userName != null && userEmail != null) {
          // Sync FCM Token on startup
          await _syncFcmToken(token);

          return AppUser(
            id: userId,
            email: userEmail,
            name: userName,
            type: userType,
          );
        }

        // Fallback if data is missing but token exists (shouldn't happen ideally)
        return AppUser(
          id: 'backend_user',
          email: 'user@backend.com',
          name: 'User',
          type: userType,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _syncFcmToken(String jwtToken) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null) {
        return;
      }

      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.updateFcmToken(fcmToken, jwtToken);
    } catch (e) {
      print('❌ Error syncing FCM token: $e');
    }
  }

  Future<void> _saveUserSession(AppUser user, String token) async {
    await SecureStorageService.instance.write(
      key: SecureStorageService.tokenKey,
      value: token,
    );
    await SecureStorageService.instance.write(
      key: SecureStorageService.userIdKey,
      value: user.id,
    );
    await SecureStorageService.instance.write(
      key: SecureStorageService.userNameKey,
      value: user.name,
    );
    await SecureStorageService.instance.write(
      key: SecureStorageService.userEmailKey,
      value: user.email,
    );
    if (user.type != null) {
      await SecureStorageService.instance.write(
        key: SecureStorageService.userTypeKey,
        value: user.type!,
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final result = await authRepository.loginWithBackend(
        email: email,
        password: password,
      );

      await _saveUserSession(result.user, result.accessToken);

      // Sync FCM Token
      await _syncFcmToken(result.accessToken);

      return result.user;
    });
  }

  Future<void> loginWithCode({required String code}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final result = await authRepository.loginWithCode(code: code);

      await _saveUserSession(result.user, result.accessToken);

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

      await _saveUserSession(result.user, result.accessToken);

      // Sync FCM Token
      await _syncFcmToken(result.accessToken);

      return result.user;
    });
  }

  Future<void> logout() async {
    await SecureStorageService.instance.deleteAll();
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
