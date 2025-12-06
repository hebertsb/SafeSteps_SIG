import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../../features/map/presentation/providers/children_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final locationTrackingProvider = AsyncNotifierProvider<LocationTrackingNotifier, void>(() {
  return LocationTrackingNotifier();
});

class LocationTrackingNotifier extends AsyncNotifier<void> {
  StreamSubscription<Position>? _subscription;

  @override
  FutureOr<void> build() {
    // Cleanup on dispose
    ref.onDispose(() {
      _stopTracking();
    });
    return null;
  }

  Future<void> startTracking() async {
    final locationService = ref.read(locationServiceProvider);
    final user = ref.read(currentUserProvider);

    if (user == null || user.type != 'hijo') {
      return;
    }

    state = const AsyncValue.loading();
    
    try {
      await locationService.startTracking();
      
      _subscription = locationService.locationStream.listen((position) async {
        try {
          // Send update to backend
          await ref.read(childrenRepositoryProvider).updateChildLocation(
            user.id,
            position.latitude,
            position.longitude,
          );
          print('Location sent to backend: ${position.latitude}, ${position.longitude}');
        } catch (e) {
          print('Error sending location to backend: $e');
        }
      });
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void stopTracking() {
    _stopTracking();
    state = const AsyncValue.data(null);
  }

  void _stopTracking() {
    _subscription?.cancel();
    ref.read(locationServiceProvider).stopTracking();
  }
}
