import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/safe_zones_repository.dart';
import '../datasources/remote_safe_zones_data_source.dart';

class SafeZonesRepositoryImpl implements SafeZonesRepository {
  final RemoteSafeZonesDataSource _dataSource;

  SafeZonesRepositoryImpl(this._dataSource);

  @override
  Future<List<SafeZone>> getSafeZones() async {
    return await _dataSource.getSafeZones();
  }

  @override
  Future<SafeZone> getSafeZoneById(String id) async {
    return await _dataSource.getSafeZoneById(id);
  }

  @override
  Future<SafeZone> createSafeZone({
    required String name,
    required String description,
    required List<List<double>> points,
    required List<int> childrenIds,
  }) async {
    return await _dataSource.createSafeZone(
      name: name,
      description: description,
      points: points,
      childrenIds: childrenIds,
    );
  }

  @override
  Future<void> deleteSafeZone(String id) async {
    await _dataSource.deleteSafeZone(id);
  }

  @override
  Future<SafeZone> updateSafeZone(String id, Map<String, dynamic> data) async {
    return await _dataSource.updateSafeZone(id, data);
  }
}
