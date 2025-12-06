import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../map/domain/entities/child.dart';

enum ZoneColor { primary, secondary, green }
enum ZoneIcon { home, school, other }

class SafeZone {
  final String id;
  final String name;
  final String description;
  final List<LatLng> points;
  final ZoneColor color;
  final ZoneIcon icon;
  final String status; // 'active' | 'inactive'
  final List<Child> children;

  SafeZone({
    required this.id,
    required this.name,
    this.description = '',
    required this.points,
    this.color = ZoneColor.primary,
    this.icon = ZoneIcon.other,
    this.status = 'active',
    this.children = const [],
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    List<LatLng> parsedPoints = [];
    if (json['poligono'] != null && json['poligono']['coordinates'] != null) {
      final coordinates = json['poligono']['coordinates'] as List;
      if (coordinates.isNotEmpty) {
        final ring = coordinates[0] as List;
        parsedPoints = ring.map((coord) {
          final c = coord as List;
          return LatLng(c[1].toDouble(), c[0].toDouble()); // GeoJSON is [lng, lat]
        }).toList();
      }
    }

    return SafeZone(
      id: json['id'].toString(),
      name: json['nombre'] ?? 'Zona Segura',
      description: json['descripcion'] ?? '',
      points: parsedPoints,
      children: (json['hijos'] as List?)
          ?.map((c) => Child.fromJson(c))
          .toList() ?? [],
      color: _getColorFromId(json['id']),
      icon: _getIconFromName(json['nombre'] ?? ''),
      status: 'active',
    );
  }

  // Helper to assign mock colors based on ID to differentiate them visually
  static ZoneColor _getColorFromId(dynamic id) {
    final intId = int.tryParse(id.toString()) ?? 0;
    final index = intId % ZoneColor.values.length;
    return ZoneColor.values[index];
  }

  // Helper to guess icon from name
  static ZoneIcon _getIconFromName(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('casa') || lowerName.contains('home')) {
      return ZoneIcon.home;
    } else if (lowerName.contains('colegio') || lowerName.contains('escuela') || lowerName.contains('school')) {
      return ZoneIcon.school;
    }
    return ZoneIcon.other;
  }

  // Helper to get Color from enum
  Color get displayColor {
    switch (color) {
      case ZoneColor.primary:
        return AppColors.primary;
      case ZoneColor.secondary:
        return Colors.orange;
      case ZoneColor.green:
        return Colors.green;
    }
  }

  // Helper to get IconData from enum
  IconData get displayIcon {
    switch (icon) {
      case ZoneIcon.home:
        return Icons.home;
      case ZoneIcon.school:
        return Icons.school;
      case ZoneIcon.other:
        return Icons.place;
    }
  }
  
  // Helper to get center of polygon for map positioning
  LatLng get center {
    if (points.isEmpty) return const LatLng(0, 0);
    double latSum = 0;
    double lngSum = 0;
    for (var p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }
}

