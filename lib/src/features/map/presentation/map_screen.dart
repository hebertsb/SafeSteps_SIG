import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import 'providers/children_provider.dart';
import '../../../core/services/socket_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../domain/entities/child.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Map<String, Child> _liveChildren = {};
  final Set<String> _joinedChildRooms = {}; // Track which rooms we've joined
  bool _socketConnected = false;

  @override
  void initState() {
    super.initState();
    _connectSocketForParent();
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
          print('🔗 Joining rooms for ${children.length} children:');
          for (var child in children) {
            if (!_joinedChildRooms.contains(child.id)) {
              print('🔗   - Child "${child.name}" with ID: "${child.id}"');
              socketService.joinChildRoom(child.id);
              _joinedChildRooms.add(child.id);
            }
          }
          _socketConnected = true;
        }
      });
      
      // Listen for location updates from children
      socketService.locationStream.listen((data) {
        print('📍 Location update received in MapScreen: $data');
        if (mounted) {
          setState(() {
            final childId = data['childId'].toString();
            print('📍 Looking for childId: "$childId"');
            
            final childrenAsync = ref.read(childrenProvider);
            childrenAsync.whenData((children) {
              print('📍 Available children IDs: ${children.map((c) => '"${c.id}"').toList()}');
              final childIndex = children.indexWhere((c) => c.id == childId);
              print('📍 Found at index: $childIndex');
              if (childIndex != -1) {
                final originalChild = children[childIndex];
                _liveChildren[childId] = originalChild.copyWith(
                  latitude: (data['lat'] as num).toDouble(),
                  longitude: (data['lng'] as num).toDouble(),
                  battery: (data['battery'] as num).toDouble(),
                  status: data['status'] as String,
                );
                print('📍 Updated _liveChildren[$childId] with new location');
              } else {
                print('⚠️ Child with ID "$childId" NOT FOUND in children list!');
              }
            });
          });
        }
      });

      // Listen for child status changes (online/offline)
      socketService.statusStream.listen((data) {
        print('👶 Status change received in MapScreen: $data');
        if (mounted) {
          setState(() {
            final childId = data['childId'].toString();
            final isOnline = data['online'] as bool;
            
            // Actualizar el estado del hijo en _liveChildren
            if (_liveChildren.containsKey(childId)) {
              _liveChildren[childId] = _liveChildren[childId]!.copyWith(
                status: isOnline ? 'online' : 'offline',
              );
              print('👶 Updated status for child $childId: ${isOnline ? "online" : "offline"}');
            } else {
              // Si no está en _liveChildren, buscarlo en children y agregarlo
              final childrenAsync = ref.read(childrenProvider);
              childrenAsync.whenData((children) {
                final childIndex = children.indexWhere((c) => c.id == childId);
                if (childIndex != -1) {
                  _liveChildren[childId] = children[childIndex].copyWith(
                    status: isOnline ? 'online' : 'offline',
                  );
                  print('👶 Added child $childId to _liveChildren with status: ${isOnline ? "online" : "offline"}');
                }
              });
            }
          });
        }
      });

      // Listen for panic alerts
      socketService.panicStream.listen((data) {
        print('🚨 Panic alert received in MapScreen: $data');
        if (mounted) {
          _showPanicAlert(data);
        }
      });
    }
  }

  void _showPanicAlert(Map<String, dynamic> data) {
    final childId = data['childId'].toString();
    final childrenAsync = ref.read(childrenProvider);
    
    childrenAsync.whenData((children) {
      final child = children.firstWhere(
        (c) => c.id == childId,
        orElse: () => Child(
          id: childId, 
          name: 'Hijo', 
          email: '',
          latitude: 0, 
          longitude: 0, 
          lastUpdated: DateTime.now(),
        ),
      );
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.red.shade50,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
              const SizedBox(width: 8),
              const Text('¡ALERTA DE PÁNICO!', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${child.name} ha enviado una alerta de emergencia.'),
              const SizedBox(height: 8),
              if (data['lat'] != null && data['lng'] != null)
                Text(
                  'Ubicación: ${data['lat']}, ${data['lng']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Parent View - Map with children locations
    final childrenAsync = ref.watch(childrenProvider);
    final socketService = ref.watch(socketServiceProvider);

    // Verificar si hay nuevos hijos para unirse a sus salas
    childrenAsync.whenData((children) {
      if (socketService.isConnected) {
        for (var child in children) {
          if (!_joinedChildRooms.contains(child.id)) {
            print('🔗 Joining room for child: "${child.name}" ID: "${child.id}"');
            socketService.joinChildRoom(child.id);
            _joinedChildRooms.add(child.id);
          }
        }
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
          // Botón de refresh para actualizar lista de hijos
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar hijos',
            onPressed: () {
              ref.invalidate(childrenProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Actualizando lista de hijos...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
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
          // DEBUG: Log de hijos cargados
          print('🗺️ Children loaded from API: ${children.length}');
          for (var c in children) {
            print('   - "${c.name}" ID: "${c.id}" lat: ${c.latitude}, lng: ${c.longitude}');
          }
          print('🗺️ Live children updates: ${_liveChildren.keys.toList()}');
          
          // Filtrar hijos con ubicación válida y aplicar datos en tiempo real
          final List<Child> displayChildren = children
              .map((child) {
                if (_liveChildren.containsKey(child.id)) {
                  final liveChild = _liveChildren[child.id]!;
                  print('🗺️ Using LIVE data for "${child.name}" (ID: ${child.id}): ${liveChild.latitude}, ${liveChild.longitude}');
                  return liveChild;
                }
                // Mark as offline if no live data received yet
                return child.copyWith(status: 'offline');
              })
              // Solo mostrar hijos con ubicación válida (lat y lng diferentes de 0)
              .where((child) => child.latitude != 0 || child.longitude != 0)
              .toList();

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
