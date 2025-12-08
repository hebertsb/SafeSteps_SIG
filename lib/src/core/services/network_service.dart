import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef OnlineStateCallback = void Function(bool isOnline);

/// Servicio para monitorear el estado de conectividad de red
/// Detecta transiciones OFFLINE → ONLINE y notifica a listeners
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  bool _isOnline = true;
  final List<OnlineStateCallback> _listeners = [];

  factory NetworkService() => _instance;
  NetworkService._internal();

  /// Inicializa el servicio de monitoreo de conectividad
  Future<void> initialize() async {
    try {
      // Obtener estado inicial
      final result = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(result);
      print('🌐 Estado inicial de red: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');

      // Escuchar cambios de conectividad
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (ConnectivityResult result) {
          _handleConnectivityChange(result);
        },
      );
    } catch (e) {
      print('❌ Error al inicializar NetworkService: $e');
      _isOnline = true; // Asumir que hay conexión por defecto
    }
  }

  /// Verifica si actualmente hay conexión a internet
  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _isConnected(result);
    } catch (e) {
      print('⚠️ Error al verificar conectividad: $e');
      return _isOnline; // Retornar estado anterior si hay error
    }
  }

  /// Obtiene el estado actual en caché (sin hacer llamada async)
  bool get isOnlineSync => _isOnline;

  /// Registra un listener para cambios de estado
  void addListener(OnlineStateCallback callback) {
    _listeners.add(callback);
    print('📲 Listener registrado (total: ${_listeners.length})');
  }

  /// Desregistra un listener
  void removeListener(OnlineStateCallback callback) {
    _listeners.remove(callback);
    print('🗑️ Listener removido (total: ${_listeners.length})');
  }

  /// Maneja cambios en la conectividad
  void _handleConnectivityChange(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = _isConnected(result);

    print('🌐 Cambio de conectividad: ${wasOnline ? 'ONLINE' : 'OFFLINE'} → ${_isOnline ? 'ONLINE' : 'OFFLINE'}');

    // Notificar solo si hubo cambio
    if (wasOnline != _isOnline) {
      _notifyListeners(_isOnline);

      if (_isOnline) {
        print('✅ INTERNET RECOVERED - Sincronizando registros pendientes');
      } else {
        print('⚠️ INTERNET LOST - Almacenando localmente');
      }
    }
  }

  /// Determina si hay conexión basado en el resultado de connectividad
  bool _isConnected(ConnectivityResult result) {
    // Verificar si el resultado es ninguno/none
    if (result == ConnectivityResult.none) {
      return false;
    }

    // Hay conexión si es WiFi, móvil o ethernet
    return result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;
  }

  /// Notifica a todos los listeners sobre cambio de estado
  void _notifyListeners(bool isOnline) {
    for (final listener in _listeners) {
      try {
        listener(isOnline);
      } catch (e) {
        print('⚠️ Error notificando listener: $e');
      }
    }
  }

  /// Espera a que se conecte internet (útil para sincronización)
  Future<void> waitForConnection({Duration timeout = const Duration(minutes: 5)}) async {
    if (_isOnline) return; // Ya hay conexión

    print('⏳ Esperando reconexión de internet (timeout: ${timeout.inSeconds}s)...');
    final completer = Completer<void>();

    OnlineStateCallback? listener;
    listener = (isOnline) {
      if (isOnline) {
        removeListener(listener!);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    };

    addListener(listener);

    try {
      await completer.future.timeout(timeout);
    } catch (e) {
      removeListener(listener);
      print('❌ Timeout esperando reconexión');
      rethrow;
    }
  }

  /// Limpieza del servicio
  void dispose() {
    print('🔌 Limpiando NetworkService');
    _connectivitySubscription.cancel();
    _listeners.clear();
  }

  /// Debug: obtiene información sobre el estado actual
  Map<String, dynamic> getDebugInfo() => {
    'isOnline': _isOnline,
    'listeners': _listeners.length,
    'timestamp': DateTime.now().toIso8601String(),
  };
}
