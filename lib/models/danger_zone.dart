import 'package:flutter/material.dart';
import '../models/location_context.dart';

class DangerZone {
  final LatLng center;
  final double radius;
  final int intensity;
  final String label;

  const DangerZone({
    required this.center,
    required this.radius,
    required this.intensity,
    this.label = 'Caution area',
  });

  Color get zoneColor {
    if (intensity >= 70) return const Color(0xFFD91E3C);
    if (intensity >= 40) return const Color(0xFFE85520);
    return const Color(0xFFE8A020);
  }
}