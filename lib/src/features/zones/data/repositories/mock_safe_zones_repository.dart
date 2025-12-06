import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/safe_zones_repository.dart';
import 'package:latlong2/latlong.dart';

class MockSafeZonesRepository implements SafeZonesRepository {
  @override
  Future<List<SafeZone>> getSafeZones() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      SafeZone(
        id: '1',
        name: 'Casa',
        description: 'Av. Las Américas 123',
        points: const [
          LatLng(-17.7833, -63.1821),
          LatLng(-17.7834, -63.1821),
          LatLng(-17.7834, -63.1822),
          LatLng(-17.7833, -63.1822),
        ],
        color: ZoneColor.primary,
        icon: ZoneIcon.home,
        status: 'active',
      ),
      SafeZone(
        id: '2',
        name: 'Colegio',
        description: 'Calle 24 de Septiembre',
        points: const [
          LatLng(-17.7900, -63.1900),
          LatLng(-17.7901, -63.1900),
          LatLng(-17.7901, -63.1901),
          LatLng(-17.7900, -63.1901),
        ],
        color: ZoneColor.secondary,
        icon: ZoneIcon.school,
        status: 'active',
      ),
    ];
  }

  @override
  Future<SafeZone> getSafeZoneById(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return (await getSafeZones()).first;
  }

  @override
  Future<SafeZone> createSafeZone({
    required String name,
    required String description,
    required List<List<double>> points,
    required List<int> childrenIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return (await getSafeZones()).first;
  }

  @override
  Future<void> deleteSafeZone(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<SafeZone> updateSafeZone(String id, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return (await getSafeZones()).first;
  }
}
