import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/zone_monitor_service.dart';
import '../../features/zones/presentation/providers/safe_zones_provider.dart';
import '../../features/notifications/presentation/providers/notifications_provider.dart';

final zoneMonitorServiceProvider = Provider<ZoneMonitorService>((ref) {
  final zonesRepository = ref.watch(safeZonesRepositoryProvider);
  final notificationsRepository = ref.watch(notificationsRepositoryProvider);
  
  return ZoneMonitorService(zonesRepository, notificationsRepository);
});
