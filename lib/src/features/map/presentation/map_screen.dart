import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import 'providers/children_provider.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);

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
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 6),
                Text('En línea', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: childrenAsync.when(
        data: (children) {
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
                      markers: children.map((child) {
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
                                      color: child.battery > 20 ? Colors.green : Colors.red,
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
                                  color: AppColors.primary,
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
                                      children.isNotEmpty ? 'Lat: ${children.first.latitude}, Lng: ${children.first.longitude}' : 'Sin ubicación',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Actualizado hace 2 minutos',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Distancia', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text('2.3 km', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
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
                                      children.isNotEmpty ? children.first.status : 'Desconocido',
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
