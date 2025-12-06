import '../entities/safe_zone.dart';

abstract class SafeZonesRepository {
  Future<List<SafeZone>> getSafeZones();
  Future<SafeZone> getSafeZoneById(String id);
  Future<SafeZone> createSafeZone({
    required String name,
    required double latitude,
    required double longitude,
    required int radius,
    required int childId,
  });
  Future<void> deleteSafeZone(String id);
  Future<SafeZone> updateSafeZone(String id, Map<String, dynamic> data);
}
