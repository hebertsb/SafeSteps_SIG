import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// ZoneMonitorService - Placeholder
/// 
/// ⚠️ NOTE: Zone detection is handled AUTOMATICALLY by the backend using PostGIS.
/// When the child's location is updated via WebSocket, the backend checks:
/// 1. If the child is inside any of their assigned safe zones (ST_Contains)
/// 2. If zone status changed (entered/exited), creates a notification in DB
/// 3. Sends FCM push notification to the tutor
/// 
/// This service is kept for potential future local caching or fallback,
/// but currently all zone detection happens server-side.
class ZoneMonitorService {
  ZoneMonitorService();

  /// Check location - deprecated, backend handles this
  Future<void> checkLocation(LatLng location) async {
    debugPrint('📍 Location update: ${location.latitude}, ${location.longitude}');
    debugPrint('🤖 Backend handles zone detection automatically with PostGIS');
  }
}
