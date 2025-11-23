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

  SafeZone({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.color,
    required this.icon,
    required this.status,
  });

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
