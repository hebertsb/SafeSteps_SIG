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

  Future<void> _showChildrenSelectionDialog(List<dynamic> children) async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.people, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Seleccionar Hijos'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: children.length,
                  itemBuilder: (context, index) {
                    final child = children[index];
                    final isSelected = _selectedChildrenIds.contains(child.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                      child: CheckboxListTile(
                        title: Text(
                          child.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        secondary: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Text(child.emoji),
                        ),
                        value: isSelected,
                        activeColor: AppColors.primary,
                        onChanged: (bool? value) {
                          setStateDialog(() {
                            if (value == true) {
                              _selectedChildrenIds.add(child.id);
                            } else {
                              _selectedChildrenIds.remove(child.id);
                            }
                          });
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Listo', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El polígono debe tener al menos 3 puntos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedChildrenIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos un hijo'),
          backgroundColor: Colors.orange,
        ),
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
      
      if (_isPolygonModified) {
        final List<List<double>> closedPoints = _polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
        if (closedPoints.isNotEmpty && closedPoints.first != closedPoints.last) {
           closedPoints.add(closedPoints.first);
        }
        updates['poligono'] = {
          "type": "Polygon",
          "coordinates": [closedPoints]
        };
      }

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
          const SnackBar(
            content: Text('✅ Zona actualizada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar zona: $e'),
            backgroundColor: Colors.red,
          ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveChanges,
        label: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Guardar Zona'),
        icon: _isLoading ? null : const Icon(Icons.save),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Mapa para editar polígono
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
                    // Polígono
                    PolygonLayer(
                      polygons: [
                        if (_polygonPoints.isNotEmpty)
                          Polygon(
                            points: _polygonPoints,
                            color: Colors.orange.withOpacity(0.3),
                            borderColor: Colors.orange,
                            borderStrokeWidth: 3,
                            isFilled: true,
                          ),
                      ],
                    ),
                    // Marcadores de vértices
                    MarkerLayer(
                      markers: _polygonPoints.map((point) {
                        return Marker(
                          point: point,
                          width: 30,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
                            ),
                            child: const Icon(Icons.drag_handle, size: 16, color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                // Controles del mapa
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
                // Instrucción
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Toca para agregar puntos. Usa deshacer para corregir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
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
                    const Text(
                      'Configuración de Zona',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Nombre de la zona
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la zona',
                        hintText: 'Ej: Casa, Escuela',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.label),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),

                    // Descripción
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción (Opcional)',
                        hintText: 'Ej: Zona segura alrededor de casa',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.description),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Selección de hijos
                    const Text('Asignar a:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    childrenAsync.when(
                      data: (children) => InkWell(
                        onTap: () => _showChildrenSelectionDialog(children),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _selectedChildrenIds.isEmpty
                                    ? Text(
                                        'Seleccionar hijos...',
                                        style: TextStyle(color: Colors.grey[600]),
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        children: children
                                            .where((c) => _selectedChildrenIds.contains(c.id))
                                            .map((c) => Chip(
                                                  avatar: Text(c.emoji),
                                                  label: Text(c.name),
                                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                                ))
                                            .toList(),
                                      ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error cargando hijos: $err', style: const TextStyle(color: Colors.red)),
                    ),
                    if (_selectedChildrenIds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Selecciona al menos un hijo',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Resumen de puntos
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.polyline, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            '${_polygonPoints.length} puntos definidos',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_polygonPoints.length < 3)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Mínimo 3',
                                style: TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80), // Space for FAB
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
