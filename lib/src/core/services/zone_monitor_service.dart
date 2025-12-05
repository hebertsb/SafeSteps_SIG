import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../features/zones/domain/repositories/safe_zones_repository.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';

class ZoneMonitorService {
  final SafeZonesRepository _zonesRepository;
  final NotificationsRepository _notificationsRepository;
  final Set<String> _insideZoneIds = {};

  ZoneMonitorService(this._zonesRepository, this._notificationsRepository);

  Future<void> checkLocation(LatLng location) async {
    try {
      final zones = await _zonesRepository.getSafeZones();
      final Distance distance = const Distance();

      for (final zone in zones) {
        final zoneLocation = LatLng(zone.latitude, zone.longitude);
        final dist = distance.as(LengthUnit.Meter, location, zoneLocation);
        final isInside = dist <= zone.radius;

        if (isInside && !_insideZoneIds.contains(zone.id)) {
          // Entered zone
          _insideZoneIds.add(zone.id);
          await _notificationsRepository.sendNotification(
            'El hijo ha entrado a la zona segura: ${zone.name}',
            'zone_entry',
          );
        } else if (!isInside && _insideZoneIds.contains(zone.id)) {
          // Exited zone
          _insideZoneIds.remove(zone.id);
          await _notificationsRepository.sendNotification(
            'El hijo ha salido de la zona segura: ${zone.name}',
            'zone_exit',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking zones: $e');
    }
  }
}
