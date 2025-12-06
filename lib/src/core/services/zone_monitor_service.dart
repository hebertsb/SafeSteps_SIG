import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../features/zones/domain/repositories/safe_zones_repository.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';

class ZoneMonitorService {
  final SafeZonesRepository _zonesRepository;
  final NotificationsRepository _notificationsRepository;

  ZoneMonitorService(this._zonesRepository, this._notificationsRepository);

  Future<void> checkLocation(LatLng location) async {
    // ⚠️ DEPRECATED: Local geofencing is no longer needed.
    // The backend now handles zone detection automatically using PostGIS.
    // This method is kept empty to avoid breaking existing dependencies until full refactor.
    debugPrint('📍 Location update received: ${location.latitude}, ${location.longitude}');
    debugPrint('🤖 Backend will handle zone detection automatically.');
  }
}
