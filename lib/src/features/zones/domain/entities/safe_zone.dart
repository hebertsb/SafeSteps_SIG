import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum ZoneColor { primary, secondary, green }
enum ZoneIcon { home, school, other }

class SafeZone {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int radius;
  final ZoneColor color;
  final ZoneIcon icon;
  final String status; // 'active' | 'inactive'
  final String? childId;

  SafeZone({
    required this.id,
    required this.name,
    this.address = '',
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.color = ZoneColor.primary,
    this.icon = ZoneIcon.other,
    this.status = 'active',
    this.childId,
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    return SafeZone(
      id: json['id'].toString(),
      name: json['nombre'] ?? 'Zona Segura',
      latitude: (json['latitud'] as num).toDouble(),
      longitude: (json['longitud'] as num).toDouble(),
      radius: json['radio'] ?? 100,
      childId: json['hijo']?['id']?.toString(),
      // Defaults for fields not in backend yet
      address: '', 
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
}

