import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/socket_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/background_location_service.dart';
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
  String? _currentChildId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _isInitialized = true;
        ref.read(locationTrackingProvider.notifier).startTracking();
        _startLocationTracking();
      }
    });
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

  @override
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
      setState(() => _lastLocationStatus = 'Solicitando permiso de segundo plano...');
      final bgStatus = await Permission.locationAlways.request();
      if (bgStatus.isDenied || bgStatus.isPermanentlyDenied) {
        print('⚠️ Background location permission denied, continuing with foreground only');
      } else {
        print('✅ Background location permission granted');
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
      
      String? jwtUserId;
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        try {
          final decoded = utf8.decode(base64Url.decode(normalized));
          print('🔑 JWT Payload: $decoded');
          
          final jsonPayload = jsonDecode(decoded);
          jwtUserId = jsonPayload['sub'].toString();
          print('🔑 JWT User ID (sub): $jwtUserId');
          print('🔑 Provider User ID: $childId');
          
          if (jwtUserId != childId) {
            print('❌ ERROR: JWT ID ($jwtUserId) NO coincide con Provider ID ($childId)!');
            setState(() => _lastLocationStatus = 'Error: Sesión inválida.');
            await ref.read(authControllerProvider.notifier).logout();
            return;
          }
          print('✅ JWT ID coincide con Provider ID');
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
          _lastLocationStatus = 'Conectado, iniciando stream GPS...';
        });
      }

      try {
        await BackgroundLocationService.instance.initialize();
        final bgServiceStarted = await BackgroundLocationService.instance.startService(token);
        if (bgServiceStarted) {
          print('✅ Background location service started');
          _isBackgroundServiceRunning = true;
        } else {
          print('⚠️ Could not start background location service');
        }
      } catch (e) {
        print('⚠️ Background service error: $e');
      }

      await _positionSubscription?.cancel();
      _positionSubscription = null;

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      final expectedChildId = childId;
      
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          if (_currentChildId != expectedChildId || !_isTracking) {
            print('⚠️ Ignoring location update - child changed or tracking stopped');
            return;
          }
          
          print('📍 Real-time Location for child $expectedChildId: ${position.latitude}, ${position.longitude}');
          
          socketService.emitLocationUpdate(
            position.latitude, 
            position.longitude, 
            85.0,
            'Activo'
          );

          _lastLat = position.latitude;
          _lastLng = position.longitude;
          _safeSetState(() {
            _lastLocationStatus = 'Compartiendo en tiempo real';
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

  void _sendPanicAlert() {
    final socketService = ref.read(socketServiceProvider);
    
    if (socketService.isConnected) {
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
              print('🚪 Logging out child: $_currentChildId');
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
            // User Info
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                currentUser?.name.substring(0, 1).toUpperCase() ?? 'H',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hola, ${currentUser?.name ?? 'Hijo'}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Tracking Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isTracking ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isTracking ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isTracking ? Icons.location_on : Icons.location_searching,
                    color: _isTracking ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _lastLocationStatus,
                    style: TextStyle(
                      color: _isTracking ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Show last coordinates if available
            if (_lastLat != null && _lastLng != null) ...[
              const SizedBox(height: 8),
              Text(
                'Lat: ${_lastLat!.toStringAsFixed(6)}, Lng: ${_lastLng!.toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            
            const SizedBox(height: 48),
            
            // SOS Button
            _buildSOSButton(
              currentUser != null ? int.tryParse(currentUser.id) : null,
              currentUser?.name,
            ),
            
            const SizedBox(height: 48),
            
            // Status Button
            OutlinedButton.icon(
              onPressed: () {
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

  Widget _buildSOSButton(int? id, String? name) {
    if (id == null) return const SizedBox.shrink();
    
    return SOSButton(
      hijoId: id,
      nombreHijo: name ?? 'Hijo',
    );
  }
}
