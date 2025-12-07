import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/socket_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/background_location_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
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
  String? _currentChildId; // Track which child this instance is for

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _isInitialized = true;
        _startLocationTracking();
      }
    });
  }
  
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      // Throttle UI updates to max 1 per second
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
    
    // Notificar al servidor que el hijo se va offline ANTES de desconectar
    final socketService = ref.read(socketServiceProvider);
    socketService.emitChildOffline();
    
    // Stop background service
    await BackgroundLocationService.instance.stopService();
    _isBackgroundServiceRunning = false;
    
    // Esperar un momento para que el mensaje se envíe
    await Future.delayed(const Duration(milliseconds: 300));
    
    socketService.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final trackingState = ref.watch(locationTrackingProvider);
    final lastLocation = ref.watch(lastLocationProvider);
  void dispose() {
    print('🗑️ Disposing child home screen for child: $_currentChildId');
    _positionSubscription?.cancel();
    _positionSubscription = null;
    super.dispose();
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
    print('DEBUG: User Email: ${user.email}');
    print('DEBUG: User Type: ${user.type}');
    print('DEBUG: Starting real-time location tracking for child: $childId');

    // 1. Check/Request permissions
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

    // Request background location permission (Android 10+)
    if (await Permission.locationAlways.isDenied) {
      setState(() => _lastLocationStatus = 'Solicitando permiso de segundo plano...');
      final bgStatus = await Permission.locationAlways.request();
      if (bgStatus.isDenied || bgStatus.isPermanentlyDenied) {
        print('⚠️ Background location permission denied, continuing with foreground only');
      } else {
        print('✅ Background location permission granted');
      }
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _lastLocationStatus = 'GPS desactivado');
      return;
    }

    try {
      // 2. Connect socket
      final socketService = ref.read(socketServiceProvider);
      final token = await SecureStorageService.instance.read(key: SecureStorageService.tokenKey);
      
      if (token == null) {
        setState(() => _lastLocationStatus = 'Error: No hay token');
        return;
      }
      
      // CRÍTICO: Verificar que el token JWT corresponde al usuario correcto
      String? jwtUserId;
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        try {
          final decoded = utf8.decode(base64Url.decode(normalized));
          print('🔑 JWT Payload: $decoded');
          
          // Extraer el ID del JWT
          final jsonPayload = jsonDecode(decoded);
          jwtUserId = jsonPayload['sub'].toString();
          print('🔑 JWT User ID (sub): $jwtUserId');
          print('🔑 Provider User ID: $childId');
          
          // Verificar que coinciden
          if (jwtUserId != childId) {
            print(' ERROR: JWT ID ($jwtUserId) NO coincide con Provider ID ($childId)!');
            print(' El token es de otro usuario. Cerrando sesión...');
            setState(() => _lastLocationStatus = 'Error: Sesión inválida. Por favor, vuelve a iniciar sesión.');
            // Forzar logout
            await ref.read(authControllerProvider.notifier).logout();
            return;
          }
          print(' JWT ID coincide con Provider ID');
        } catch (e) {
          print(' Could not decode JWT: $e');
        }
      }

      // Guardar el childId actual para esta instancia
      _currentChildId = childId;

      // Desconectar cualquier socket anterior y conectar con el nuevo token
      socketService.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
      socketService.connect(token);
      
      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!socketService.isConnected) {
        setState(() => _lastLocationStatus = 'Error de conexión al servidor');
        return;
      }

      // Join child room
      socketService.joinChildRoom(childId);
      
      // Emit online status
      socketService.emitChildOnline();

      if (mounted) {
        setState(() {
          _isTracking = true;
          _lastLocationStatus = 'Conectado, iniciando stream GPS...';
        });
      }

      // Start background service for when app is closed
      // First initialize (creates notification channel), then start
      try {
        await BackgroundLocationService.instance.initialize();
        final bgServiceStarted = await BackgroundLocationService.instance.startService(token);
        if (bgServiceStarted) {
          print(' Background location service started');
          _isBackgroundServiceRunning = true;
        } else {
          print(' Could not start background location service');
        }
      } catch (e) {
        print(' Background service error: $e');
        // Continue without background service - foreground tracking still works
      }

      // Cancelar cualquier subscription anterior antes de crear una nueva
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      // 3. Usar stream de ubicación en TIEMPO REAL
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Solo emitir si se movió al menos 5 metros
      );

      // Capturar el childId en el closure para validación
      final expectedChildId = childId;
      
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          // CRÍTICO: Verificar que seguimos siendo el mismo hijo
          if (_currentChildId != expectedChildId || !_isTracking) {
            print(' Ignoring location update - child changed or tracking stopped');
            return;
          }
          
          print(' Real-time Location for child $expectedChildId: ${position.latitude}, ${position.longitude}');
          
          // El backend obtiene el childId del JWT, no necesitamos enviarlo
          socketService.emitLocationUpdate(
            position.latitude, 
            position.longitude, 
            85.0, // TODO: Get actual battery level
            'Activo'
          );

          _lastLat = position.latitude;
          _lastLng = position.longitude;
          _safeSetState(() {
            _lastLocationStatus = 'Compartiendo en tiempo real';
          });
        },
        onError: (error) {
          print(' Location stream error: $error');
          if (_lastLat == null) {
            _safeSetState(() => _lastLocationStatus = 'Error de GPS');
          }
        },
      );

    } catch (e, stack) {
      print(' Error in _startLocationTracking: $e');
      print(stack);
      if (mounted) {
        setState(() => _lastLocationStatus = 'Error: $e');
      }
    }
  }

  void _sendPanicAlert() {
    final socketService = ref.read(socketServiceProvider);
    
    if (socketService.isConnected) {
      // Emit panic alert via socket (el backend obtiene childId del JWT)
      socketService.emitPanicAlert(_lastLat ?? 0, _lastLng ?? 0);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Alerta de pánico enviada!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No hay conexión con el servidor'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final socketService = ref.watch(socketServiceProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Modo Hijo', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          // Connection status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: socketService.isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  socketService.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  socketService.isConnected ? 'Online' : 'Offline',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              print(' Logging out child: $_currentChildId');
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
            // Header Profile
            _buildProfileHeader(currentUser?.name ?? 'Hijo'),
            const SizedBox(height: 30),

            // Status Dashboard
            _buildStatusDashboard(trackingState, lastLocation),
            const SizedBox(height: 30),

            // SOS Button
            _buildSOSButton(
              currentUser != null ? int.tryParse(currentUser.id) : null,
              currentUser?.name,
            ),
            const SizedBox(height: 30),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hola, $name',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.green),
              SizedBox(width: 4),
              Text(
                'Protección Activa',
                style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDashboard(AsyncValue<void> trackingState, DateTime? lastUpdate) {
    final isTracking = !trackingState.isLoading && !trackingState.hasError;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusItem(
                icon: isTracking ? Icons.gps_fixed : Icons.gps_off,
                color: isTracking ? Colors.blue : Colors.grey,
                label: 'GPS',
                value: isTracking ? 'Activo' : 'Inactivo',
              ),
              _buildVerticalDivider(),
              _buildStatusItem(
                icon: Icons.access_time,
                color: Colors.orange,
                label: 'Última vez',
                value: lastUpdate != null 
                  ? DateFormat('HH:mm:ss').format(lastUpdate)
                  : '--:--',
              ),
              _buildVerticalDivider(),
              _buildStatusItem(
                icon: Icons.battery_std,
                color: Colors.green,
                label: 'Batería',
                value: '95%', // TODO: Get real battery level
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          // Zone Status Placeholder
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado de Zona',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      'Monitoreado por el Tutor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSOSButton(int? id, String? name) {
    if (id == null) return const SizedBox.shrink();
    
    return SOSButton(
      hijoId: id,
      nombreHijo: name ?? 'Hijo',
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(locationTrackingProvider.notifier).startTracking();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ubicación actualizada manualmente'),
              backgroundColor: Colors.green,
            ),
            
            const SizedBox(height: 48),
            
            // Status Button
            OutlinedButton.icon(
              onPressed: () {
                // El stream ya está emitiendo en tiempo real, solo mostrar confirmación
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isTracking 
                      ? 'Ubicación compartida: $_lastLat, $_lastLng' 
                      : 'Esperando conexión GPS...'),
                    backgroundColor: _isTracking ? Colors.green : Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Estoy bien'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
