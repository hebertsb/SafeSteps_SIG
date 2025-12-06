import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../map/presentation/providers/children_provider.dart';
import '../domain/entities/safe_zone.dart';
import 'providers/safe_zones_provider.dart';

class EditZoneScreen extends ConsumerStatefulWidget {
  final SafeZone zone;

  const EditZoneScreen({super.key, required this.zone});

  @override
  ConsumerState<EditZoneScreen> createState() => _EditZoneScreenState();
}

class _EditZoneScreenState extends ConsumerState<EditZoneScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final _mapController = MapController();
  
  late List<LatLng> _polygonPoints;
  late List<String> _selectedChildrenIds;
  bool _isLoading = false;
  bool _isPolygonModified = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.zone.name);
    _descriptionController = TextEditingController(text: widget.zone.description);
    _polygonPoints = List.from(widget.zone.points);
    _selectedChildrenIds = widget.zone.children.map((c) => c.id).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _polygonPoints.add(point);
      _isPolygonModified = true;
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _isPolygonModified = true;
      });
    }
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _isPolygonModified = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El polígono debe tener al menos 3 puntos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> updates = {};

      if (_nameController.text != widget.zone.name) {
        updates['nombre'] = _nameController.text;
      }
      if (_descriptionController.text != widget.zone.description) {
        updates['descripcion'] = _descriptionController.text;
      }
      
      // Always send polygon if modified, or maybe check if points changed
      if (_isPolygonModified) {
         // Ensure closed polygon
        final List<List<double>> closedPoints = _polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
        if (closedPoints.isNotEmpty && closedPoints.first != closedPoints.last) {
           closedPoints.add(closedPoints.first);
        }

        updates['poligono'] = {
          "type": "Polygon",
          "coordinates": [closedPoints]
        };
      }

      // Check if children changed
      final originalIds = widget.zone.children.map((c) => c.id).toSet();
      final newIds = _selectedChildrenIds.toSet();
      if (originalIds.length != newIds.length || !originalIds.containsAll(newIds)) {
        updates['hijosIds'] = _selectedChildrenIds.map((id) => int.parse(id)).toList();
      }

      if (updates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay cambios para guardar')),
        );
        setState(() => _isLoading = false);
        return;
      }

      await ref.read(safeZonesProvider.notifier).updateSafeZone(widget.zone.id, updates);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zona actualizada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar zona: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Zona Segura'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mapa
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.zone.center,
                    initialZoom: 15.0,
                    onTap: _handleTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.safesteps.safe_steps_mobile',
                    ),
                    PolygonLayer(
                      polygons: [
                        if (_polygonPoints.isNotEmpty)
                          Polygon(
                            points: _polygonPoints,
                            color: Colors.orange.withOpacity(0.3),
                            borderColor: Colors.orange,
                            borderStrokeWidth: 2,
                            isFilled: true,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: _polygonPoints.map((point) => Marker(
                        point: point,
                        width: 12,
                        height: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'undo_edit',
                        mini: true,
                        onPressed: _polygonPoints.isNotEmpty ? _undoLastPoint : null,
                        backgroundColor: _polygonPoints.isNotEmpty ? Colors.white : Colors.grey[300],
                        child: const Icon(Icons.undo, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'clear_edit',
                        mini: true,
                        onPressed: _polygonPoints.isNotEmpty ? _clearPolygon : null,
                        backgroundColor: _polygonPoints.isNotEmpty ? Colors.white : Colors.grey[300],
                        child: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Formulario
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la zona',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    const Text('Asignar a:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    childrenAsync.when(
                      data: (children) => Wrap(
                        spacing: 8.0,
                        children: children.map((child) {
                          final isSelected = _selectedChildrenIds.contains(child.id);
                          return FilterChip(
                            label: Text(child.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedChildrenIds.add(child.id);
                                } else {
                                  _selectedChildrenIds.remove(child.id);
                                }
                              });
                            },
                            avatar: Text(child.emoji),
                            selectedColor: AppColors.primary.withOpacity(0.2),
                            checkmarkColor: AppColors.primary,
                          );
                        }).toList(),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error: $err'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
