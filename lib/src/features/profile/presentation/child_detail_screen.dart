import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/socket_provider.dart';
import '../../map/domain/entities/child.dart';
import '../../map/presentation/providers/children_provider.dart';

class ChildDetailScreen extends ConsumerStatefulWidget {
  final Child child;

  const ChildDetailScreen({super.key, required this.child});

  @override
  ConsumerState<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends ConsumerState<ChildDetailScreen> {
  bool _isRegenerating = false;
  late Child _liveChild;
  StreamSubscription? _locationSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _liveChild = widget.child;
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    final socketService = ref.read(socketServiceProvider);
    
    // Listen for location updates
    _locationSub = socketService.locationStream.listen((data) {
      if (mounted && data['childId'].toString() == widget.child.id) {
        final newDevice = data['device'] as String? ?? 'Unknown';
        setState(() {
          _liveChild = _liveChild.copyWith(
            latitude: (data['lat'] as num).toDouble(),
            longitude: (data['lng'] as num).toDouble(),
            battery: (data['battery'] as num).toDouble(),
            status: 'online',
            device: newDevice != 'Unknown' ? newDevice : _liveChild.device,
            lastUpdated: DateTime.now(),
          );
        });
      }
    });

    // Listen for status changes
    _statusSub = socketService.statusStream.listen((data) {
      if (mounted && data['childId'].toString() == widget.child.id) {
        final isOnline = data['online'] as bool;
        final newDevice = data['device'] as String? ?? 'Unknown';
        setState(() {
          _liveChild = _liveChild.copyWith(
            status: isOnline ? 'online' : 'offline',
            device: newDevice != 'Unknown' ? newDevice : _liveChild.device,
            lastUpdated: DateTime.now(),
          );
        });
      }
    });

    // Join the child's room if not already
    if (socketService.isConnected) {
      socketService.joinChildRoom(widget.child.id);
    }
  }

  Future<void> _regenerateCode() async {
    // Mostrar confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerar Código'),
        content: Text(
          '¿Deseas regenerar el código de vinculación de ${widget.child.name}?\n\n'
          '⚠️ El código anterior quedará inválido.\n'
          '✅ El nuevo código permitirá acceder desde un nuevo dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.notification,
            ),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRegenerating = true);

    try {
      final repository = ref.read(childrenRepositoryProvider);
      final newCode = await repository.regenerateCode(widget.child.id);

      if (mounted) {
        // Refrescar la lista de hijos
        ref.invalidate(childrenProvider);

        // Mostrar diálogo con el nuevo código
        await _showNewCodeDialog(newCode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  Future<void> _showNewCodeDialog(String newCode) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de éxito
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 50,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                '¡Código Regenerado!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 8),

              // Nombre del hijo
              Text(
                widget.child.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // Mensaje
              Text(
                'Comparte este nuevo código con tu hijo para que pueda ingresar desde su dispositivo móvil:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),

              // Código de vinculación
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[300]!, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      newCode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        fontFamily: 'Courier',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: newCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Código copiado al portapapeles'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado al portapapeles'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.child.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta de información del hijo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.child.emoji,
                        style: const TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nombre
                  Text(
                    widget.child.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _liveChild.status == 'online'
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _liveChild.status == 'online'
                              ? Colors.green.shade700
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _liveChild.status == 'online'
                              ? 'En línea'
                              : 'Desconectado',
                          style: TextStyle(
                            color: _liveChild.status == 'online'
                                ? Colors.green.shade700
                                : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Información
                  _buildInfoRow(Icons.email, 'Email', widget.child.email),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.phone,
                    'Teléfono',
                    widget.child.phone.toString(),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.phone_android,
                    'Dispositivo',
                    _liveChild.device,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.battery_std,
                    'Batería',
                    '${_liveChild.battery.toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sección de Código de Vinculación
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.key, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Código de Vinculación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Código actual
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.child.codigoVinculacion ?? 'Sin código',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            fontFamily: 'Courier',
                          ),
                        ),
                        IconButton(
                          onPressed: widget.child.codigoVinculacion != null
                              ? () => _copyCode(widget.child.codigoVinculacion!)
                              : null,
                          icon: const Icon(Icons.copy),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mensaje de advertencia
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Al regenerar el código, el anterior quedará inválido. '
                            'El nuevo código permitirá acceder desde un nuevo dispositivo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón de regenerar
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isRegenerating ? null : _regenerateCode,
                      icon: _isRegenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _isRegenerating ? 'Regenerando...' : 'Regenerar Código',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.notification,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
