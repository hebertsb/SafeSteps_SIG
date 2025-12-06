import '../entities/safe_zone.dart';

abstract class SafeZonesRepository {
  Future<List<SafeZone>> getSafeZones();
  Future<SafeZone> getSafeZoneById(String id);
  Future<SafeZone> createSafeZone({
    required String name,
    required String description,
    required List<List<double>> points, // [[lng, lat]]
    required List<int> childrenIds,
  });
  Future<void> deleteSafeZone(String id);
  Future<SafeZone> updateSafeZone(String id, Map<String, dynamic> data);
}
