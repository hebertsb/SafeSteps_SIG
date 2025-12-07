import 'package:flutter/material.dart';
import 'package:safe_steps_mobile/src/core/models/registro.dart';

/// Widget para mostrar el historial de ubicaciones de un hijo
class LocationHistoryPanel extends StatefulWidget {
  final String hijoId;
  final String childName;
  final String childEmoji;
  final List<Registro> registros;
  final void Function(Registro)? onCenterOnPoint;
  final bool isLoadingHistory;
  final bool showSyncStatus;

  const LocationHistoryPanel({
    Key? key,
    required this.hijoId,
    required this.childName,
    required this.childEmoji,
    required this.registros,
    this.onCenterOnPoint,
    this.isLoadingHistory = false,
    this.showSyncStatus = true,
  }) : super(key: key);

  @override
  State<LocationHistoryPanel> createState() => _LocationHistoryPanelState();
}

class _LocationHistoryPanelState extends State<LocationHistoryPanel> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final pendingCount = widget.registros.where((r) => !r.isSynced).length;
    final syncedCount = widget.registros.where((r) => r.isSynced).length;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle para mostrar/ocultar historial
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              onTap: () => setState(() => _showHistory = !_showHistory),
              trailing: AnimatedRotation(
                turns: _showHistory ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.expand_more_rounded),
              ),
              title: const Text(
                'Historial de ubicaciones',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${widget.registros.length} registros (${syncedCount} sincronizados, ${pendingCount} pendientes)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),

          // Contenedor expandible con el historial
          if (_showHistory && widget.registros.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.registros.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final registro = widget.registros[index];
                  final isSynced = registro.isSynced;
                  final timeString = _formatTime(registro.hora);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSynced 
                                ? Colors.green.shade50 
                                : Colors.orange.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSynced 
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300,
                            ),
                          ),
                          child: Icon(
                            isSynced 
                                ? Icons.check_rounded 
                                : Icons.cloud_upload_rounded,
                            size: 16,
                            color: isSynced 
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      timeString,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${registro.latitud.toStringAsFixed(4)}, ${registro.longitud.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          onTap: () => _centerOnPoint(registro),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Ver en mapa'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Mensajes si no hay datos
          if (_showHistory && widget.registros.isEmpty && !widget.isLoadingHistory)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin registros disponibles',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los registros de ubicación aparecerán aquí',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

          // Loading state
          if (_showHistory && widget.isLoadingHistory)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(32),
              child: const CircularProgressIndicator(),
            ),

          // Resumen de sincronización
          if (widget.showSyncStatus)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pendingCount > 0 
                    ? Colors.orange.shade50 
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: pendingCount > 0 
                      ? Colors.orange.shade300
                      : Colors.green.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    pendingCount > 0 
                        ? Icons.cloud_upload_rounded 
                        : Icons.check_circle_rounded,
                    color: pendingCount > 0 
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pendingCount > 0 
                              ? '$pendingCount ubicaciones pendientes de sincronización'
                              : 'Todos los registros están sincronizados',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pendingCount > 0 
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$syncedCount registros sincronizados correctamente',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _centerOnPoint(Registro registro) {
    widget.onCenterOnPoint?.call(registro);
    Navigator.pop(context);
  }

  String _formatTime(dynamic time) {
    if (time is! DateTime) return 'N/A';
    final now = DateTime.now();
    final formatter = _TimeFormatter();
    
    if (now.year == time.year && now.month == time.month && now.day == time.day) {
      return formatter.formatTime(time);
    } else {
      return formatter.formatDateTime(time);
    }
  }
}

/// Clase auxiliar para formatear tiempo
class _TimeFormatter {
  String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String formatDateTime(DateTime time) {
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${time.day} ${months[time.month - 1]} ${formatTime(time)}';
  }
}
