import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'providers/safe_zones_provider.dart';

class ZonesScreen extends ConsumerWidget {
  const ZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(safeZonesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SafeSteps', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Ubicación en tiempo real', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header con título y botón
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zonas Seguras',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configurar áreas de confianza',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    context.push('/create-zone');
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          
          // Lista de zonas
          Expanded(
            child: Container(
              color: AppColors.background,
              child: zonesAsync.when(
                data: (zones) => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: zones.length + 1, // +1 para el consejo
                  itemBuilder: (context, index) {
                    if (index == zones.length) {
                      // Tarjeta de consejo al final
                      return Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 28),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Consejo',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Recibirás notificaciones cuando tu hijo entre o salga de estas zonas seguras.',
                                    style: TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    final zone = zones[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: zone.displayColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(zone.displayIcon, color: zone.displayColor, size: 28),
                        ),
                        title: Text(
                          zone.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.description, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    zone.description.isNotEmpty ? zone.description : 'Sin descripción',
                                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: zone.status == 'active' ? Colors.green.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: zone.status == 'active' ? Colors.green.shade700 : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        zone.status == 'active' ? 'Activa' : 'Inactiva',
                                        style: TextStyle(
                                          color: zone.status == 'active' ? Colors.green.shade700 : Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.polyline, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${zone.points.length} puntos',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  context.push('/edit-zone', extra: zone);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Eliminar Zona Segura'),
                                      content: Text('¿Estás seguro de eliminar "${zone.name}"?\n\nEsta acción no se puede deshacer.'),
                                      actions: [
                                        TextButton(
                                          child: const Text('Cancelar'),
                                          onPressed: () => Navigator.pop(context, false),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirm == true) {
                                    await ref.read(safeZonesProvider.notifier).deleteSafeZone(zone.id);
                                  }
                                },
                              ),
                            ],
                          ),
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
