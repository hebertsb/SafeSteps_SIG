import 'dart:math' as math;
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

    // Ordena todos los registros primero para conectar correctamente
    final sortedRegistros = List<Registro>.from(registros)
      ..sort((a, b) => a.hora.compareTo(b.hora));

    final polylines = <Polyline>[];

    // Construir segmentos conectando puntos consecutivos
    // con el color según el estado de cada segmento
    for (int i = 0; i < sortedRegistros.length - 1; i++) {
      final current = sortedRegistros[i];
      final next = sortedRegistros[i + 1];
      
      // El color del segmento depende del punto de destino
      final isOfflineSegment = next.fueOffline;
      
      if (isOfflineSegment && !showOfflineRoute) continue;
      if (!isOfflineSegment && !showOnlineRoute) continue;

      polylines.add(
        Polyline(
          points: [
            LatLng(current.latitud, current.longitud),
            LatLng(next.latitud, next.longitud),
          ],
          color: isOfflineSegment 
              ? Colors.orange.shade500 
              : Colors.green.shade600,
          strokeWidth: 4.0,
          pattern: isOfflineSegment 
              ? StrokePattern.dashed(segments: const [8, 6])
              : StrokePattern.solid(),
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }

    return polylines;
  }
}

/// Widget para mostrar flechas de dirección en la ruta
class RouteArrowsLayer extends StatelessWidget {
  final List<Registro> registros;

  const RouteArrowsLayer({
    Key? key,
    required this.registros,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (registros.length < 2) return const SizedBox.shrink();

    final sortedRegistros = List<Registro>.from(registros)
      ..sort((a, b) => a.hora.compareTo(b.hora));

    final markers = <Marker>[];
    
    // Agregar flechas cada 2-3 puntos para indicar dirección
    for (int i = 1; i < sortedRegistros.length - 1; i += 2) {
      final prev = sortedRegistros[i - 1];
      final current = sortedRegistros[i];
      
      // Calcular ángulo de dirección
      final angle = _calculateBearing(
        prev.latitud, prev.longitud,
        current.latitud, current.longitud,
      );
      
      final isOffline = current.fueOffline;

      markers.add(
        Marker(
          point: LatLng(current.latitud, current.longitud),
          width: 24,
          height: 24,
          child: Transform.rotate(
            angle: angle,
            child: Icon(
              Icons.navigation_rounded,
              color: isOffline ? Colors.orange.shade700 : Colors.green.shade700,
              size: 20,
            ),
          ),
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    return math.atan2(y, x);
  }
}

/// Widget para mostrar los marcadores de cada punto en la ruta
class RoutePointsMarker extends StatelessWidget {
  final List<Registro> registros;
  final Function(Registro)? onTap;
  final bool showOnlinePoints;
  final bool showOfflinePoints;
  final bool showNumbers;

  const RoutePointsMarker({
    Key? key,
    required this.registros,
    this.onTap,
    this.showOnlinePoints = true,
    this.showOfflinePoints = true,
    this.showNumbers = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();
    return MarkerLayer(markers: markers);
  }

  List<Marker> _buildMarkers() {
    if (registros.isEmpty) return [];
    
    // Ordenar por hora para numeración correcta
    final sortedRegistros = List<Registro>.from(registros)
      ..sort((a, b) => a.hora.compareTo(b.hora));
    
    return sortedRegistros
        .asMap()
        .entries
        .where((entry) {
          final wasOffline = entry.value.fueOffline;
          if (!wasOffline) return showOnlinePoints;
          return showOfflinePoints;
        })
        .map((entry) {
          final index = entry.key;
          final registro = entry.value;
          final wasOffline = registro.fueOffline;
          final isFirst = index == 0;
          final isLast = index == sortedRegistros.length - 1;
          final pointNumber = index + 1;

          // Marcadores de inicio y fin más grandes
          if (isFirst || isLast) {
            return Marker(
              point: LatLng(registro.latitud, registro.longitud),
              width: 56,
              height: 56,
              child: GestureDetector(
                onTap: () => onTap?.call(registro),
                child: _buildSpecialMarker(isFirst, isLast, pointNumber),
              ),
            );
          }

          // Marcadores intermedios con número
          return Marker(
            point: LatLng(registro.latitud, registro.longitud),
            width: 32,
            height: 32,
            child: GestureDetector(
              onTap: () => onTap?.call(registro),
              child: _buildNumberedMarker(pointNumber, wasOffline),
            ),
          );
        })
        .toList();
  }

  Widget _buildSpecialMarker(bool isFirst, bool isLast, int number) {
    final color = isFirst ? Colors.green.shade600 : Colors.red.shade600;
    final icon = isFirst ? Icons.flag_rounded : Icons.sports_score_rounded;
    final label = isFirst ? 'INICIO' : 'FIN';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildNumberedMarker(int number, bool wasOffline) {
    final color = wasOffline ? Colors.orange.shade500 : Colors.green.shade500;
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: showNumbers && number <= 99
            ? Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
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
