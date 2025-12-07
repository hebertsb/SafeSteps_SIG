import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_steps_mobile/src/core/models/registro.dart';
import 'package:safe_steps_mobile/src/core/services/sync_service.dart';

/// Proveedor de instancia del SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

/// Proveedor para obtener todos los registros de un hijo específico
final locationHistoryProvider = FutureProvider.family<List<Registro>, String>((ref, hijoId) async {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.obtenerPendientesByHijo(hijoId);
});

/// Proveedor para obtener registros de un rango de fechas
final locationHistoryByDateProvider = FutureProvider.family<List<Registro>, ({String hijoId, DateTime date, DateTime? endDate})>((ref, params) async {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.obtenerPorFecha(params.hijoId, params.date, params.endDate ?? params.date);
});

/// Proveedor para obtener estadísticas de sincronización
final syncStatisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.obtenerEstadisticas();
});

/// Proveedor para monitorear cambios de sincronización
final syncStatusProvider = StreamProvider<({String event, int pendingCount, bool isOnline})>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  
  final completer = Future<void>.value();
  
  return Stream.empty();
});
