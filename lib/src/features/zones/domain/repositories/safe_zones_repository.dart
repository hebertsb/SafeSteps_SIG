import '../entities/safe_zone.dart';

abstract class SafeZonesRepository {
  Future<List<SafeZone>> getSafeZones();
  Future<void> addSafeZone(SafeZone zone);
}
