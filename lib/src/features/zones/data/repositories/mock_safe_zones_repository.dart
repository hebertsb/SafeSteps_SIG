import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/safe_zones_repository.dart';

class MockSafeZonesRepository implements SafeZonesRepository {
  @override
  Future<List<SafeZone>> getSafeZones() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      SafeZone(
        id: '1',
        name: 'Casa',
        address: 'Av. Las Américas 123',
        latitude: -17.7833,
        longitude: -63.1821,
        radius: 100,
        color: ZoneColor.primary,
        icon: ZoneIcon.home,
        status: 'active',
      ),
      SafeZone(
        id: '2',
        name: 'Colegio',
        address: 'Calle 24 de Septiembre',
        latitude: -17.7900,
        longitude: -63.1900,
        radius: 200,
        color: ZoneColor.secondary,
        icon: ZoneIcon.school,
        status: 'active',
      ),
    ];
  }

  @override
  Future<void> addSafeZone(SafeZone zone) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
