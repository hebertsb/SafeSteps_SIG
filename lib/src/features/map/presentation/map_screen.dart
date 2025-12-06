import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import 'providers/children_provider.dart';
import '../../../core/services/socket_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../domain/entities/child.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Map<String, Child> _liveChildren = {};
  bool _joinedRooms = false;
  bool _isChild = false;
  bool _isTracking = false;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _checkUserTypeAndConnect();
  }

  Future<void> _checkUserTypeAndConnect() async {
    final user = ref.read(currentUserProvider);
    print('DEBUG: Current User: ${user?.name}, Type: ${user?.type}, ID: ${user?.id}');
    
    // Normalize type check (handle null, lowercase, uppercase)
    final userType = user?.type?.toLowerCase() ?? '';
    
    if (userType == 'hijo') {
      print('DEBUG: User identified as CHILD. Starting location tracking...');
      setState(() {
        _isChild = true;
      });
      _startLocationTracking(user!.id);
    } else {
      print('DEBUG: User identified as PARENT (or unknown). Connecting as parent...');
      _connectSocketForParent();
    }
  }

  Future<void> _startLocationTracking(String childId) async {
    print('DEBUG: Starting _startLocationTracking for $childId');
    
    // 1. Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('DEBUG: Permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('DEBUG: Permission denied forever');
      return;
    }

    try {
      // 2. Connect socket
      final socketService = ref.read(socketServiceProvider);
      final token = await SecureStorageService.instance.read(key: SecureStorageService.tokenKey);
      
      if (token != null) {
        socketService.connect(token);
        
        // Wait for connection before joining
        await Future.delayed(const Duration(milliseconds: 1000));
        
        socketService.joinChildRoom(childId);
        
        if (mounted) {
          setState(() => _isTracking = true);
        }

        // 3. Listen to location changes
        // Use Timer.periodic instead of Stream for emulator reliability
        // Increased to 5s to prevent timeouts on emulator
        Timer.periodic(const Duration(seconds: 5), (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }
          
          // Prevent overlapping fetches
          if (_isFetchingLocation) return;
          _isFetchingLocation = true;
          
          try {
            // Force Android Location Manager which is often more reliable on emulators
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              forceAndroidLocationManager: true,
              timeLimit: const Duration(seconds: 4)
            );
            
            print('📍 New Location: ${position.latitude}, ${position.longitude}');
            
            socketService.emitLocationUpdate(
              childId, 
              position.latitude, 
              position.longitude, 
              85.0, 
              'En movimiento'
            );
          } catch (e) {
            print('❌ Error fetching location: $e');
          } finally {
            _isFetchingLocation = false;
          }
        });
      } else {
        print('❌ No token found, cannot connect socket');
      }
    } catch (e, stack) {
      print('❌ Error in _startLocationTracking: $e');
      print(stack);
    }
  }

  Future<void> _connectSocketForParent() async {
    final socketService = ref.read(socketServiceProvider);
    final token = await SecureStorageService.instance.read(key: SecureStorageService.tokenKey);
    
    if (token != null) {
      socketService.connect(token);
      
      // Wait for connection to ensure we can join rooms
      int retries = 0;
      while (!socketService.isConnected && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }

      // Re-trigger room joining
      final childrenAsync = ref.read(childrenProvider);
      childrenAsync.whenData((children) {
        if (socketService.isConnected) {
          for (var child in children) {
            print('DEBUG: Joining room for child ${child.id}');
            socketService.joinChildRoom(child.id);
          }
          _joinedRooms = true;
        }
      });
      
      socketService.locationStream.listen((data) {
        print('📍 Location update received in MapScreen: $data');
        if (mounted) {
          setState(() {
            final childId = data['childId'].toString();
            
            final childrenAsync = ref.read(childrenProvider);
            childrenAsync.whenData((children) {
              final childIndex = children.indexWhere((c) => c.id == childId);
              if (childIndex != -1) {
                final originalChild = children[childIndex];
                _liveChildren[childId] = originalChild.copyWith(
                  latitude: (data['lat'] as num).toDouble(),
                  longitude: (data['lng'] as num).toDouble(),
                  battery: (data['battery'] as num).toDouble(),
                  status: data['status'] as String,
                );
              }
            });
          });
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If user is a Child, show a different screen
    if (_isChild) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modo Hijo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on, 
                size: 64, 
                color: _isTracking ? Colors.green : Colors.grey
              ),
              const SizedBox(height: 16),
              Text(
                _isTracking ? 'Compartiendo ubicación...' : 'Iniciando rastreo...',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu ubicación se está enviando a tus padres en tiempo real.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Parent View (Existing Map Logic)
    final childrenAsync = ref.watch(childrenProvider);
    final socketService = ref.watch(socketServiceProvider);

    // Join rooms when children are loaded (Backup trigger)
    childrenAsync.whenData((children) {
      if (!_joinedRooms && socketService.isConnected) {
        for (var child in children) {
          socketService.joinChildRoom(child.id);
        }
        _joinedRooms = true;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SafeSteps', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Ubicación en tiempo real', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: socketService.isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.white, size: 8),
                const SizedBox(width: 6),
                Text(socketService.isConnected ? 'En línea' : 'Desconectado', 
                     style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: childrenAsync.when(
        data: (children) {
          // Show ALL children. If we have live data, use it. Otherwise, show as offline.
          final List<Child> displayChildren = children.map((child) {
            if (_liveChildren.containsKey(child.id)) {
              return _liveChildren[child.id]!;
            }
            // Mark as offline if no live data received yet
            return child.copyWith(status: 'offline');
          }).toList();

          return Column(
            children: [
              // Mapa - Ocupa solo la mitad superior
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(-17.7833, -63.1821), // Santa Cruz
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.safesteps.safe_steps_mobile',
                    ),
                    MarkerLayer(
                      markers: displayChildren.map((child) {
                        final isOffline = child.status == 'offline';
                        return Marker(
                          point: LatLng(child.latitude, child.longitude),
                          width: 80,
                          height: 100,
                          child: Column(
                            children: [
                              // Indicador de batería
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.battery_full,
                                      size: 14,
                                      color: isOffline ? Colors.grey : (child.battery > 20 ? Colors.green : Colors.red),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${child.battery.toInt()}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Marcador del niño
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isOffline ? Colors.grey : AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    child.emoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              // Nombre del niño
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  child.name,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              
              // Información debajo del mapa
              Expanded(
                child: Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      // Tarjeta de Ubicación Actual
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, color: AppColors.primary, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ubicación Actual',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      displayChildren.isNotEmpty ? 'Lat: ${displayChildren.first.latitude.toStringAsFixed(4)}, Lng: ${displayChildren.first.longitude.toStringAsFixed(4)}' : 'Sin ubicación',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Actualizado en tiempo real',
                                      style: TextStyle(fontSize: 12, color: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                              // ... (rest of the card)
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Tarjetas de Zona y Estado
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(Icons.shield, color: Colors.green.shade700, size: 32),
                                    const SizedBox(height: 8),
                                    const Text('Zona', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text('Segura', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    const Text('🏃', style: TextStyle(fontSize: 32)),
                                    const SizedBox(height: 8),
                                    const Text('Estado', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(
                                      displayChildren.isNotEmpty ? displayChildren.first.status : 'Desconocido',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                    ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Historial Reciente
                      const Text(
                        'Historial Reciente',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildHistoryItem(
                        icon: Icons.school,
                        color: Colors.green,
                        title: 'Escuela',
                        time: '14:30 - 17:45',
                        duration: '3 horas',
                      ),
                      
                      const SizedBox(height: 8),
                      
                      _buildHistoryItem(
                        icon: Icons.home,
                        color: Colors.orange,
                        title: 'Casa',
                        time: '12:00 - 14:15',
                        duration: '5 horas',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
  
  Widget _buildHistoryItem({
    required IconData icon,
    required Color color,
    required String title,
    required String time,
    required String duration,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            duration,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
