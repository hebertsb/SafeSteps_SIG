import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/zone_monitor_service.dart';

final zoneMonitorServiceProvider = Provider<ZoneMonitorService>((ref) {
  return ZoneMonitorService();
});
