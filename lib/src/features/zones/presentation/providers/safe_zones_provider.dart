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
  SafeZonesRepository get _repository => ref.read(safeZonesRepositoryProvider);

  @override
  Future<List<SafeZone>> build() async {
    return _repository.getSafeZones();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getSafeZones());
  }

  Future<void> addSafeZone({
    required String name,
    required String description,
    required List<List<double>> points,
    required List<int> childrenIds,
  }) async {
    final previousState = state;
    try {
      final newZone = await _repository.createSafeZone(
        name: name,
        description: description,
        points: points,
        childrenIds: childrenIds,
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
  Future<void> updateSafeZone(String id, Map<String, dynamic> data) async {
    final previousState = state;
    try {
      final updatedZone = await _repository.updateSafeZone(id, data);
      if (previousState.hasValue) {
        state = AsyncValue.data(
          previousState.value!.map((zone) => zone.id == id ? updatedZone : zone).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error updating safe zone: $e');
      throw e;
    }
  }
}

final safeZonesProvider = AsyncNotifierProvider<SafeZonesNotifier, List<SafeZone>>(() {
  return SafeZonesNotifier();
});
