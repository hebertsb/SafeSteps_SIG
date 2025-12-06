
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../map/presentation/providers/children_provider.dart';
import 'providers/safe_zones_provider.dart';

class CreateZoneScreen extends ConsumerStatefulWidget {
  const CreateZoneScreen({super.key});

  @override
  ConsumerState<CreateZoneScreen> createState() => _CreateZoneScreenState();
}

class _CreateZoneScreenState extends ConsumerState<CreateZoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mapController = MapController();
  
  final List<LatLng> _polygonPoints = [];
  final List<String> _selectedChildrenIds = [];
  bool _isLoading = false;
  
  // Default center (Santa Cruz)
  final LatLng _initialCenter = const LatLng(-17.7833, -63.1821);

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
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
      });
    }
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
    });
  }



  Future<void> _showChildrenSelectionDialog(List<dynamic> children) async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Seleccionar Hijos'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: children.length,
                  itemBuilder: (context, index) {
                    final child = children[index];
                    final isSelected = _selectedChildrenIds.contains(child.id);
                    return CheckboxListTile(
                      title: Text(child.name),
                      secondary: Text(child.emoji),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            _selectedChildrenIds.add(child.id);
                          } else {
                            _selectedChildrenIds.remove(child.id);
                          }
                        });
                        // Update parent state as well to reflect changes immediately if needed
                        setState(() {}); 
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Listo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveZone() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dibuja un polígono con al menos 3 puntos')),
      );
      return;
    }

    if (_selectedChildrenIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona al menos un hijo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert LatLng list to List<List<double>> for backend
      final points = _polygonPoints.map((p) => [p.longitude, p.latitude]).toList();

      await ref.read(safeZonesProvider.notifier).addSafeZone(
        name: _nameController.text,
        description: _descriptionController.text,
        points: points,
        childrenIds: _selectedChildrenIds.map((id) => int.parse(id)).toList(),
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zona segura creada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear zona: $e')),
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
        title: const Text('Nueva Zona Segura'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveZone,
        label: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Guardar Zona'),
        icon: _isLoading ? null : const Icon(Icons.save),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Mapa para dibujar polígono
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 15.0,
                    onTap: _handleTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.safesteps.safe_steps_mobile',
                    ),
                    // Polígono dibujado
                    PolygonLayer(
                      polygons: [
                        if (_polygonPoints.isNotEmpty)
                          Polygon(
                            points: _polygonPoints,
                            color: Colors.blue.withOpacity(0.3),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2,
                            isFilled: true,
                          ),
                      ],
                    ),
                    // Marcadores de vértices (Draggable)
                    MarkerLayer(
                      markers: _polygonPoints.map((point) {
                        return Marker(
                          point: point,
                          width: 30,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
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
                        heroTag: 'undo',
                        mini: true,
                        onPressed: _polygonPoints.isNotEmpty ? _undoLastPoint : null,
                        backgroundColor: _polygonPoints.isNotEmpty ? Colors.white : Colors.grey[300],
                        child: const Icon(Icons.undo, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'clear',
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
                      'Toca para agregar. Usa deshacer para corregir.',
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
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la zona',
                        hintText: 'Ej: Casa, Escuela',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
 
                    // Descripción
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (Opcional)',
                        hintText: 'Ej: Zona segura alrededor de casa',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Selección de hijos (Dropdown style)
                    const Text('Asignar a:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    childrenAsync.when(
                      data: (children) => InkWell(
                        onTap: () => _showChildrenSelectionDialog(children),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedChildrenIds.isEmpty
                                      ? 'Seleccionar hijos...'
                                      : '${_selectedChildrenIds.length} hijo(s) seleccionado(s)',
                                  style: TextStyle(
                                    color: _selectedChildrenIds.isEmpty ? Colors.grey[600] : Colors.black,
                                  ),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.polyline, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '${_polygonPoints.length} puntos definidos',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_polygonPoints.length < 3)
                            const Text(
                              'Mínimo 3 requeridos',
                              style: TextStyle(color: Colors.orange, fontSize: 12),
                            )
                          else
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
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
