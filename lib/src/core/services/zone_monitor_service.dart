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

      for (final zone in zones) {
        final isInside = _isPointInPolygon(location, zone.points);

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

  // Ray Casting algorithm to check if point is inside polygon
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    
    bool isInside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude) &&
          (point.longitude < (polygon[j].longitude - polygon[i].longitude) * 
          (point.latitude - polygon[i].latitude) / 
          (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude)) {
        isInside = !isInside;
      }
      j = i;
    }
    
    return isInside;
  }
}
