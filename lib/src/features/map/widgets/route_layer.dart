import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_steps_mobile/src/core/models/registro.dart';

/// Clase para gestionar la visualización de rutas en el mapa
class RouteLayer extends StatelessWidget {
  final List<Registro> registros;
  final bool showOfflineRoute;
  final bool showOnlineRoute;

  const RouteLayer({
    Key? key,
    required this.registros,
    this.showOfflineRoute = true,
    this.showOnlineRoute = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final polylines = _buildPolylines();
    return PolylineLayer(polylines: polylines);
  }

  /// Construye las polylines para visualizar las rutas
  List<Polyline> _buildPolylines() {
    if (registros.isEmpty) return [];

    // Separa registros sinchronizados y pendientes
    final syncedRegistros = registros.where((r) => r.isSynced).toList();
    final pendingRegistros = registros.where((r) => !r.isSynced).toList();

    // Ordena por hora para dibujar la ruta correctamente
    syncedRegistros.sort((a, b) => a.hora.compareTo(b.hora));
    pendingRegistros.sort((a, b) => a.hora.compareTo(b.hora));

    final polylines = <Polyline>[];

    // Polyline para registros sincronizados (ruta en línea)
    if (showOnlineRoute && syncedRegistros.isNotEmpty) {
      polylines.add(
        Polyline(
          points: syncedRegistros
              .map((r) => LatLng(r.latitud, r.longitud))
              .toList(),
          color: Colors.green.shade600,
          strokeWidth: 3.5,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }

    // Polyline para registros pendientes (ruta offline)
    if (showOfflineRoute && pendingRegistros.isNotEmpty) {
      polylines.add(
        Polyline(
          points: pendingRegistros
              .map((r) => LatLng(r.latitud, r.longitud))
              .toList(),
          color: Colors.orange.shade500,
          strokeWidth: 3.5,
          pattern: StrokePattern.dashed(segments: const [5, 5]),
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }

    return polylines;
  }
}

/// Widget para mostrar los marcadores de cada punto en la ruta
class RoutePointsMarker extends StatelessWidget {
  final List<Registro> registros;
  final Function(Registro)? onTap;
  final bool showOnlinePoints;
  final bool showOfflinePoints;

  const RoutePointsMarker({
    Key? key,
    required this.registros,
    this.onTap,
    this.showOnlinePoints = true,
    this.showOfflinePoints = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();
    return MarkerLayer(markers: markers);
  }

  List<Marker> _buildMarkers() {
    return registros
        .asMap()
        .entries
        .where((entry) {
          final isSynced = entry.value.isSynced;
          if (isSynced) return showOnlinePoints;
          return showOfflinePoints;
        })
        .map((entry) {
          final index = entry.key;
          final registro = entry.value;
          final isSynced = registro.isSynced;
          final isFirst = index == 0;
          final isLast = index == registros.length - 1;

          return Marker(
            point: LatLng(registro.latitud, registro.longitud),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => onTap?.call(registro),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getPointColor(isSynced, isFirst, isLast),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getPointColor(isSynced, isFirst, isLast)
                          .withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _getPointIcon(isFirst, isLast, isSynced),
                ),
              ),
            ),
          );
        })
        .toList();
  }

  Color _getPointColor(bool isSynced, bool isFirst, bool isLast) {
    if (isFirst) {
      return Colors.blue.shade600; // Punto de inicio
    } else if (isLast) {
      return Colors.red.shade600; // Punto final
    } else {
      return isSynced 
          ? Colors.green.shade500 
          : Colors.orange.shade500;
    }
  }

  Widget _getPointIcon(bool isFirst, bool isLast, bool isSynced) {
    if (isFirst) {
      return const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18);
    } else if (isLast) {
      return const Icon(Icons.stop_rounded, color: Colors.white, size: 18);
    } else {
      return Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    }
  }
}

/// Widget informativo que muestra leyenda de colores
class RouteLegend extends StatelessWidget {
  final bool showOfflineRoute;
  final bool showOnlineRoute;
  final VoidCallback? onToggleOffline;
  final VoidCallback? onToggleOnline;

  const RouteLegend({
    Key? key,
    required this.showOfflineRoute,
    required this.showOnlineRoute,
    this.onToggleOffline,
    this.onToggleOnline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          const Text(
            'Leyenda de rutas',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Ruta en línea
          GestureDetector(
            onTap: onToggleOnline,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: showOnlineRoute 
                        ? Colors.green.shade600 
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ruta sincronizada',
                    style: TextStyle(
                      fontSize: 11,
                      color: showOnlineRoute 
                          ? Colors.green.shade700
                          : Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  showOnlineRoute 
                      ? Icons.visibility_rounded 
                      : Icons.visibility_off_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Ruta offline
          GestureDetector(
            onTap: onToggleOffline,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: showOfflineRoute 
                        ? Colors.orange.shade500 
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: showOfflineRoute
                      ? CustomPaint(
                          painter: _DashedLinePainter(Colors.orange.shade500),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ruta offline (pendiente)',
                    style: TextStyle(
                      fontSize: 11,
                      color: showOfflineRoute 
                          ? Colors.orange.shade700
                          : Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  showOfflineRoute 
                      ? Icons.visibility_rounded 
                      : Icons.visibility_off_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Leyenda de puntos
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendPoint(
                  color: Colors.blue.shade600,
                  icon: Icons.play_arrow_rounded,
                  label: 'Inicio',
                ),
                const SizedBox(height: 6),
                _LegendPoint(
                  color: Colors.green.shade500,
                  icon: null,
                  label: 'Puntos en línea',
                ),
                const SizedBox(height: 6),
                _LegendPoint(
                  color: Colors.red.shade600,
                  icon: Icons.stop_rounded,
                  label: 'Fin',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget auxiliar para mostrar cada punto de la leyenda
class _LegendPoint extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String label;

  const _LegendPoint({
    required this.color,
    this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 10)
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

/// Painter personalizado para dibujar líneas punteadas
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
