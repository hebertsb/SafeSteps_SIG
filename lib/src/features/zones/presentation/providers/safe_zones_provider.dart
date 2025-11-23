import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/safe_zones_repository.dart';
import '../../data/repositories/mock_safe_zones_repository.dart';

final safeZonesRepositoryProvider = Provider<SafeZonesRepository>((ref) {
  return MockSafeZonesRepository();
});

final safeZonesProvider = FutureProvider<List<SafeZone>>((ref) async {
  final repository = ref.read(safeZonesRepositoryProvider);
  return repository.getSafeZones();
});
