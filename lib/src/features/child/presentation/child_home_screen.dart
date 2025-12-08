import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/socket_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/background_location_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/models/registro.dart';
import '../../../core/providers/location_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../sos/presentation/widgets/sos_button.dart';

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  bool _isTracking = false;
  bool _isInitialized = false;
  bool _isBackgroundServiceRunning = false;
  StreamSubscription<Position>? _positionSubscription;
  String _lastLocationStatus = 'Iniciando...';
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastUIUpdate;
  DateTime? _lastLocationTime;
  String? _currentChildId;
  
  // Battery
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  StreamSubscription<BatteryState>? _batterySubscription;
  
  // Device info
  String _deviceName = 'Unknown';

  // Sync & Offline Support
  late SyncService _syncService;
  late NetworkService _networkService;
  int _pendingRecords = 0;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _initBattery();
    _initSyncServices(); // Inicializar servicios de sync
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isInitialized) {
        _isInitialized = true;
        // Wait for device info before starting location tracking
        await _initDeviceInfo();
        _startLocationTracking();
      }
    });
  }

  Future<void> _initBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batterySubscription = _battery.onBatteryStateChanged.listen((_) async {
        final level = await _battery.batteryLevel;
        if (mounted && level != _batteryLevel) {
          setState(() => _batteryLevel = level);
        }
      });
    } catch (e) {
      print('Error getting battery: $e');
      _batteryLevel = 100;
    }
    if (mounted) setState(() {});
  }

  /// Inicializa los servicios de sincronización offline/online
  void _initSyncServices() {
    try {
      _syncService = SyncService();
      _networkService = NetworkService();

      // Inicializar servicios de forma async sin bloquear UI
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await _syncService.initialize();
          
          // Agregar listener para cambios de sincronización
          _syncService.addSyncListener(_onSyncStatusChange);
          
          // Actualizar estado inicial
          final stats = await _syncService.obtenerEstadisticas();
          final pending = stats['pending'] ?? 0;
          final online = await _syncService.isOnline();
          
          if (mounted) {
            setState(() {
              _pendingRecords = pending;
              _isOnline = online;
            });
          }
          
          print('✅ Servicios de sync inicializados');
        } catch (e) {
          print('⚠️ Error inicializando sync services: $e');
        }
      });
    } catch (e) {
      print('❌ Error en _initSyncServices: $e');
    }
  }

  /// Callback cuando cambia el estado de sincronización
  void _onSyncStatusChange(bool success, int synced) {
    if (mounted) {
      setState(() {
        _pendingRecords = _pendingRecords > synced ? _pendingRecords - synced : 0;
      });
      
      if (success && synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $synced ubicaciones sincronizadas'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Future<void> _initDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceName = iosInfo.name ?? iosInfo.model;
      }
      print('📱 Device name: $_deviceName');
    } catch (e) {
      print('Error getting device info: $e');
      _deviceName = 'Unknown';
    }
  }

  @override
  void dispose() {
    print('🗑️ Disposing child home screen for child: $_currentChildId');
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _batterySubscription?.cancel();
    
    // Limpiar servicios de sync
    _syncService.removeSyncListener(_onSyncStatusChange);
    _syncService.dispose();
    _networkService.dispose();
    
    super.dispose();
  }
  
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      final now = DateTime.now();
      if (_lastUIUpdate == null || now.difference(_lastUIUpdate!).inMilliseconds > 1000) {
        _lastUIUpdate = now;
        setState(fn);
      }
    }
  }

  Future<void> _cleanup() async {
    print('🧹 Cleaning up child home screen for child: $_currentChildId');
    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    
    final socketService = ref.read(socketServiceProvider);
    socketService.emitChildOffline();
    
    await BackgroundLocationService.instance.stopService();
    _isBackgroundServiceRunning = false;
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    socketService.disconnect();
  }

  /// Updates child location via HTTP PATCH to trigger backend zone detection with PostGIS
  Future<void> _updateLocationOnBackend(double lat, double lng) async {
    try {
      final token = await SecureStorageService.instance.read(
        key: SecureStorageService.tokenKey,
      );
      
      if (token == null || _currentChildId == null) return;
      
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000';
      final url = Uri.parse('$baseUrl/hijos/$_currentChildId/location');
      
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitud': lat,
          'longitud': lng,
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ Location updated on backend - zone detection triggered');
      } else {
        print('⚠️ Backend location update failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error updating location on backend: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _lastLocationStatus = 'Error: Usuario no encontrado');
      return;
    }

    final childId = user.id;
    print('DEBUG: ===== CHILD HOME SCREEN =====');
    print('DEBUG: User ID from provider: $childId');
    print('DEBUG: User Name: ${user.name}');

    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _lastLocationStatus = 'Permiso de ubicación denegado');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _lastLocationStatus = 'Permiso denegado permanentemente');
      return;
    }

    if (await Permission.locationAlways.isDenied) {
      setState(() => _lastLocationStatus = 'Solicitando permiso...');
      final bgStatus = await Permission.locationAlways.request();
      if (bgStatus.isDenied || bgStatus.isPermanentlyDenied) {
        print('⚠️ Background location permission denied');
      }
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _lastLocationStatus = 'GPS desactivado');
      return;
    }

    try {
      final socketService = ref.read(socketServiceProvider);
      final token = await SecureStorageService.instance.read(key: SecureStorageService.tokenKey);
      
      if (token == null) {
        setState(() => _lastLocationStatus = 'Error: No hay token');
        return;
      }
      
      // Validate JWT
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        try {
          final decoded = utf8.decode(base64Url.decode(normalized));
          final jsonPayload = jsonDecode(decoded);
          final jwtUserId = jsonPayload['sub'].toString();
          
          if (jwtUserId != childId) {
            setState(() => _lastLocationStatus = 'Error: Sesión inválida.');
            await ref.read(authControllerProvider.notifier).logout();
            return;
          }
        } catch (e) {
          print('⚠️ Could not decode JWT: $e');
        }
      }

      _currentChildId = childId;

      socketService.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
      socketService.connect(token);
      
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!socketService.isConnected) {
        setState(() => _lastLocationStatus = 'Error de conexión al servidor');
        return;
      }

      socketService.joinChildRoom(childId);
      socketService.emitChildOnline();

      if (mounted) {
        setState(() {
          _isTracking = true;
          _lastLocationStatus = 'Conectado';
        });
      }

      // Background service
      try {
        await BackgroundLocationService.instance.initialize();
        final bgServiceStarted = await BackgroundLocationService.instance.startService(token);
        if (bgServiceStarted) {
          _isBackgroundServiceRunning = true;
        }
      } catch (e) {
        print('⚠️ Background service error: $e');
      }

      await _positionSubscription?.cancel();
      _positionSubscription = null;

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,   // 5 metros
      );

      final expectedChildId = childId;
      
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          if (_currentChildId != expectedChildId || !_isTracking) {
            return;
          }
          
          // 1. Send location with real battery level via WebSocket (for real-time map)
          socketService.emitLocationUpdate(
            position.latitude, 
            position.longitude, 
            _batteryLevel.toDouble(),
            'Activo',
            device: _deviceName,
          );
          
          // 2. Also send via HTTP to trigger backend zone detection with PostGIS
          _updateLocationOnBackend(position.latitude, position.longitude);

          // 3. NUEVO: Registrar ubicación en el sistema de sync (online/offline)
          // Si hay internet: envía directamente
          // Si no hay internet: guarda localmente para sincronizar después
          _registrarUbicacionConSync(
            position.latitude,
            position.longitude,
            childId,
          );

          _lastLat = position.latitude;
          _lastLng = position.longitude;
          _lastLocationTime = DateTime.now();
          _safeSetState(() {
            _lastLocationStatus = 'Compartiendo ubicación';
          });
        },
        onError: (error) {
          print('❌ Location stream error: $error');
          if (_lastLat == null) {
            _safeSetState(() => _lastLocationStatus = 'Error de GPS');
          }
        },
      );

    } catch (e, stack) {
      print('❌ Error in _startLocationTracking: $e');
      print(stack);
      if (mounted) {
        setState(() => _lastLocationStatus = 'Error: $e');
      }
    }
  }

  /// Registra una ubicación en el sistema de sincronización offline/online
  /// - Si hay internet: envía directamente al servidor
  /// - Si no hay internet: guarda localmente para sincronizar después
  Future<void> _registrarUbicacionConSync(
    double latitud,
    double longitud,
    String hijoId,
  ) async {
    try {
      await _syncService.registrarUbicacion(
        latitud: latitud,
        longitud: longitud,
        hijoId: hijoId,
      );

      // Actualizar estadísticas
      final stats = await _syncService.obtenerEstadisticas();
      final pending = stats['pending'] ?? 0;
      final isOnline = await _syncService.isOnline();
      
      if (mounted && pending != _pendingRecords) {
        setState(() => _pendingRecords = pending);
      }
      
      // Si hay internet Y hay registros pendientes, forzar sincronización
      if (isOnline && pending > 0) {
        print('🔄 Forzando sincronización: $pending registros pendientes');
        await _syncService.syncPendingRecords();
        
        // Actualizar conteo después de sincronizar
        final newStats = await _syncService.obtenerEstadisticas();
        final newPending = newStats['pending'] ?? 0;
        if (mounted) {
          setState(() => _pendingRecords = newPending);
        }
      }
    } catch (e) {
      print('⚠️ Error registrando ubicación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final socketService = ref.watch(socketServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          _buildConnectionIndicator(socketService.isConnected),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _cleanup();
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildProfileCard(currentUser?.name ?? 'Hijo'),
            const SizedBox(height: 24),
            _buildStatusCard(),
            const SizedBox(height: 24),
            _buildSOSSection(
              currentUser != null ? int.tryParse(currentUser.id) : null,
              currentUser?.name,
            ),
            const SizedBox(height: 24),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator(bool isConnected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Conectado' : 'Sin conexión',
            style: TextStyle(
              color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String name) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'H',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Hola!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Protegido',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado del Dispositivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusTile(
                  icon: _isTracking ? Icons.gps_fixed : Icons.gps_off,
                  iconColor: _isTracking ? Colors.green : Colors.orange,
                  label: 'GPS',
                  value: _isTracking ? 'Activo' : 'Inactivo',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusTile(
                  icon: _getBatteryIcon(),
                  iconColor: _getBatteryColor(),
                  label: 'Batería',
                  value: '$_batteryLevel%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusTile(
                  icon: Icons.access_time,
                  iconColor: Colors.blue,
                  label: 'Última',
                  value: _lastLocationTime != null 
                    ? DateFormat('HH:mm').format(_lastLocationTime!)
                    : '--:--',
                ),
              ),
            ],
          ),
          if (_lastLat != null && _lastLng != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_lastLat!.toStringAsFixed(5)}, ${_lastLng!.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // NUEVA SECCIÓN: Estado de sincronización
          if (_pendingRecords > 0 || !_isOnline) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isOnline ? Colors.amber.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isOnline ? Colors.amber.shade200 : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOnline ? Icons.cloud_queue : Icons.cloud_off,
                    color: _isOnline ? Colors.amber.shade700 : Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? 'Sincronizando' : 'Modo Sin Conexión',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isOnline ? Colors.amber.shade700 : Colors.red.shade700,
                          ),
                        ),
                        if (_pendingRecords > 0)
                          Text(
                            '$_pendingRecords ubicaciones pendientes',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBatteryIcon() {
    if (_batteryLevel > 80) return Icons.battery_full;
    if (_batteryLevel > 60) return Icons.battery_5_bar;
    if (_batteryLevel > 40) return Icons.battery_4_bar;
    if (_batteryLevel > 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  Color _getBatteryColor() {
    if (_batteryLevel > 60) return Colors.green;
    if (_batteryLevel > 20) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSOSSection(int? id, String? name) {
    if (id == null) return const SizedBox.shrink();
    
    return Column(
      children: [
        const Text(
          '¿Necesitas ayuda?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Presiona el botón SOS para alertar a tu tutor',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        SOSButton(
          hijoId: id,
          nombreHijo: name ?? 'Hijo',
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones Rápidas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isTracking 
                      ? '✓ Tu ubicación está siendo compartida' 
                      : 'Conectando...'),
                    backgroundColor: _isTracking ? Colors.green : Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Estoy bien'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.green.shade400),
                foregroundColor: Colors.green.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
