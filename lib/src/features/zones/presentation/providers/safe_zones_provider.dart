import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/safe_zones_repository.dart';
import '../../data/datasources/remote_safe_zones_data_source.dart';
import '../../data/repositories/safe_zones_repository_impl.dart';

final safeZonesRepositoryProvider = Provider<SafeZonesRepository>((ref) {
  return SafeZonesRepositoryImpl(
    RemoteSafeZonesDataSourceImpl(client: http.Client()),
  );
});

class SafeZonesNotifier extends AsyncNotifier<List<SafeZone>> {
  late final SafeZonesRepository _repository;

  @override
  Future<List<SafeZone>> build() async {
    _repository = ref.read(safeZonesRepositoryProvider);
    return _repository.getSafeZones();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getSafeZones());
  }

  Future<void> addSafeZone({
    required String name,
    required double latitude,
    required double longitude,
    required int radius,
    required int childId,
  }) async {
    final previousState = state;
    try {
      final newZone = await _repository.createSafeZone(
        name: name,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        childId: childId,
      );
      if (previousState.hasValue) {
        state = AsyncValue.data([...previousState.value!, newZone]);
      } else {
        refresh();
      }
    } catch (e) {
      // Handle error
      debugPrint('Error adding safe zone: $e');
    }
  }

  Future<void> deleteSafeZone(String id) async {
    final previousState = state;
    try {
      await _repository.deleteSafeZone(id);
      if (previousState.hasValue) {
        state = AsyncValue.data(
          previousState.value!.where((zone) => zone.id != id).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error deleting safe zone: $e');
    }
  }
}

final safeZonesProvider = AsyncNotifierProvider<SafeZonesNotifier, List<SafeZone>>(() {
  return SafeZonesNotifier();
});
