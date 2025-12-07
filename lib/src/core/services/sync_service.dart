import 'dart:async';
import '../models/registro.dart';
import '../services/registro_sqlite.dart';
import '../services/registro_api.dart';
import '../services/network_service.dart';

typedef OnSyncCallback = void Function(bool success, int synced);

/// Servicio central para sincronización offline/online de registros
/// Orquesta la sincronización de datos locales cuando hay conexión
class SyncService {
  static final SyncService _instance = SyncService._internal();
  
  final RegistroSQLite _sqlite = RegistroSQLite();
  final RegistroApi _api = RegistroApi();
  final NetworkService _network = NetworkService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  final List<OnSyncCallback> _syncListeners = [];

  factory SyncService() => _instance;
  SyncService._internal();

  /// Inicializa el servicio de sincronización
  Future<void> initialize() async {
    try {
      print('🚀 Inicializando SyncService');
      
      // Inicializar NetworkService
      await _network.initialize();
      
      // Agregar listener para cambios de conectividad
      _network.addListener(_onConnectivityChange);
      
      // Iniciar timer de sincronización periódica
      _startSyncTimer();
      
      print('✅ SyncService inicializado');
    } catch (e) {
      print('❌ Error inicializando SyncService: $e');
      rethrow;
    }
  }

  /// Listener para cambios de conectividad (OFFLINE → ONLINE)
  Future<void> _onConnectivityChange(bool isOnline) async {
    if (isOnline) {
      print('📶 ¡Internet recuperado! Sincronizando registros pendientes...');
      await syncPendingRecords();
    } else {
      print('📵 Internet perdido. Futuras ubicaciones se almacenarán localmente.');
    }
  }

  /// Inicia timer para sincronización periódica (cada 30 segundos si hay conexión)
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (_network.isOnlineSync && !_isSyncing) {
          print('⏰ Timer de sincronización periódica activado');
          await syncPendingRecords();
        }
      },
    );
    print('⏱️ Timer de sincronización iniciado (cada 30s)');
  }

  /// Sincroniza todos los registros pendientes con el backend
  /// Estrategia:
  /// 1. Obtener registros locales isSynced = false
  /// 2. Agrupar por hijoId
  /// 3. Enviar batch por hijo
  /// 4. Marcar como sincronizados si éxito
  /// 5. Notificar listeners
  Future<void> syncPendingRecords() async {
    if (_isSyncing) {
      print('⏸️ Sincronización ya en progreso');
      return;
    }

    if (!_network.isOnlineSync) {
      print('⚠️ No hay conexión. Esperando reconexión...');
      return;
    }

    _isSyncing = true;

    try {
      print('🔄 Iniciando sincronización de registros pendientes...');

      // Obtener registros pendientes
      final pendientes = await _sqlite.getPendientes();

      if (pendientes.isEmpty) {
        print('✅ No hay registros pendientes para sincronizar');
        _notifySyncListeners(true, 0);
        return;
      }

      print('📋 Encontrados ${pendientes.length} registros pendientes');

      // Agrupar por hijoId
      final Map<String, List<Registro>> registrosPorHijo = {};
      for (final registro in pendientes) {
        if (!registrosPorHijo.containsKey(registro.hijoId)) {
          registrosPorHijo[registro.hijoId] = [];
        }
        registrosPorHijo[registro.hijoId]!.add(registro);
      }

      int totalSincronizados = 0;
      bool todoExitoso = true;

      // Sincronizar por hijo
      for (final entry in registrosPorHijo.entries) {
        final hijoId = entry.key;
        final registros = entry.value;

        print('👶 Sincronizando ${registros.length} registros para hijo: $hijoId');

        // Enviar batch
        final success = await _api.enviarBatch(registros, hijoId);

        if (success) {
          // Marcar como sincronizados
          final ids = registros
              .whereType<Registro>()
              .map((r) => int.tryParse(r.id ?? ''))
              .whereType<int>()
              .toList();

          if (ids.isNotEmpty) {
            await _sqlite.marcarMultipleComoSynced(ids);
            totalSincronizados += ids.length;
            print('✅ ${ids.length} registros marcados como sincronizados');
          }
        } else {
          todoExitoso = false;
          print('❌ Error sincronizando registros del hijo $hijoId');
        }
      }

      if (todoExitoso) {
        print('✅ Sincronización completada exitosamente');
        print('📊 Total sincronizados: $totalSincronizados');
      } else {
        print('⚠️ Sincronización parcial - algunos registros no se pudieron enviar');
      }

      _notifySyncListeners(todoExitoso, totalSincronizados);
    } catch (e) {
      print('❌ Error durante sincronización: $e');
      _notifySyncListeners(false, 0);
    } finally {
      _isSyncing = false;
    }
  }

  /// Registra un registro nuevo (online o offline)
  /// Decide si enviar directamente o guardar localmente
  Future<bool> registrarUbicacion({
    required double latitud,
    required double longitud,
    required String hijoId,
    String? horaPersonalizada,
  }) async {
    try {
      final registro = Registro(
        hora: horaPersonalizada ?? DateTime.now().toIso8601String(),
        latitud: latitud,
        longitud: longitud,
        hijoId: hijoId,
        isSynced: false,
      );

      final isOnline = await _network.isOnline();

      if (isOnline) {
        print('🌐 Enviando ubicación al backend (ONLINE)');
        final success = await _api.enviarRegistroIndividual(registro);

        if (success) {
          print('✅ Ubicación enviada exitosamente');
          return true;
        } else {
          print('⚠️ Fallo envío. Guardando localmente para reintentar');
          await _sqlite.insertRegistro(registro);
          return false;
        }
      } else {
        print('📵 OFFLINE - Guardando ubicación localmente');
        await _sqlite.insertRegistro(registro);
        return true;
      }
    } catch (e) {
      print('❌ Error registrando ubicación: $e');
      return false;
    }
  }

  /// Obtiene registros pendientes sin sincronizar
  Future<List<Registro>> obtenerPendientes() async {
    try {
      return await _sqlite.getPendientes();
    } catch (e) {
      print('❌ Error obteniendo pendientes: $e');
      return [];
    }
  }

  /// Obtiene registros pendientes de un hijo específico
  Future<List<Registro>> obtenerPendientesByHijo(String hijoId) async {
    try {
      return await _sqlite.getPendientesByHijo(hijoId);
    } catch (e) {
      print('❌ Error obteniendo pendientes: $e');
      return [];
    }
  }

  /// Obtiene todos los registros (locales)
  Future<List<Registro>> obtenerTodosRegistros() async {
    try {
      return await _sqlite.getAllRegistros();
    } catch (e) {
      print('❌ Error obteniendo registros: $e');
      return [];
    }
  }

  /// Obtiene registros por rango de fechas
  Future<List<Registro>> obtenerPorFecha(
    String hijoId,
    DateTime desde,
    DateTime hasta,
  ) async {
    try {
      return await _sqlite.getRegistrosByFecha(hijoId, desde, hasta);
    } catch (e) {
      print('❌ Error obteniendo registros por fecha: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de sincronización
  Future<Map<String, int>> obtenerEstadisticas() async {
    try {
      return await _sqlite.getEstadisticas();
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {};
    }
  }

  /// Fuerza sincronización inmediata
  Future<void> forceSyncNow() async {
    print('⚡ Forzando sincronización inmediata');
    await syncPendingRecords();
  }

  /// Verifica estado actual de red
  Future<bool> isOnline() => _network.isOnline();

  /// Obtiene estado en caché (sin async)
  bool get isOnlineSync => _network.isOnlineSync;

  /// Registra listener para cambios de sincronización
  void addSyncListener(OnSyncCallback callback) {
    _syncListeners.add(callback);
  }

  /// Desregistra listener de sincronización
  void removeSyncListener(OnSyncCallback callback) {
    _syncListeners.remove(callback);
  }

  /// Notifica listeners sobre resultado de sincronización
  void _notifySyncListeners(bool success, int synced) {
    for (final listener in _syncListeners) {
      try {
        listener(success, synced);
      } catch (e) {
        print('⚠️ Error en sync listener: $e');
      }
    }
  }

  /// Limpia registros sincronizados (mantenimiento)
  Future<int> limpiarSincronizados() async {
    try {
      return await _sqlite.limpiarSincronizados();
    } catch (e) {
      print('❌ Error limpiando sincronizados: $e');
      return 0;
    }
  }

  /// Obtiene información de debug
  Map<String, dynamic> getDebugInfo() => {
    'isOnline': _network.isOnlineSync,
    'isSyncing': _isSyncing,
    'timerActive': _syncTimer?.isActive ?? false,
    'syncListeners': _syncListeners.length,
    'networkDebug': _network.getDebugInfo(),
  };

  /// Limpieza del servicio
  void dispose() {
    print('🔌 Limpiando SyncService');
    _syncTimer?.cancel();
    _network.removeListener(_onConnectivityChange);
    _syncListeners.clear();
    _network.dispose();
  }
}
