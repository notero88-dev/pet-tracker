import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Geofence model
class Geofence {
  final int id;
  final String name;
  final String area; // WKT format (e.g., "CIRCLE(lat lon radius)")
  final int? deviceId; // Linked device (null = all devices)
  final DateTime createdAt;
  final bool isActive;
  final Map<String, dynamic>? attributes;

  // Parsed data from WKT
  GeofenceType? _type;
  LatLng? _center;
  double? _radius;
  List<LatLng>? _polygonPoints;

  Geofence({
    required this.id,
    required this.name,
    required this.area,
    this.deviceId,
    required this.createdAt,
    this.isActive = true,
    this.attributes,
  }) {
    _parseArea();
  }

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] as int,
      name: json['name'] as String,
      area: json['area'] as String,
      deviceId: json['deviceId'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'area': area,
      'deviceId': deviceId,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'attributes': attributes,
    };
  }

  /// Parse WKT area format
  void _parseArea() {
    try {
      if (area.startsWith('CIRCLE')) {
        _type = GeofenceType.circle;
        
        // Parse: CIRCLE(lat lon radius_in_degrees)
        final coords = area
            .substring(7, area.length - 1) // Remove "CIRCLE(" and ")"
            .split(' ');
        
        if (coords.length >= 3) {
          final lat = double.parse(coords[0]);
          final lon = double.parse(coords[1]);
          final radiusDegrees = double.parse(coords[2]);
          
          _center = LatLng(lat, lon);
          _radius = radiusDegrees * 111000; // Convert degrees to meters (approx)
        }
      } else if (area.startsWith('POLYGON')) {
        _type = GeofenceType.polygon;
        
        // Parse: POLYGON((lat1 lon1, lat2 lon2, ...))
        final coordsStr = area
            .substring(9, area.length - 2) // Remove "POLYGON((" and "))"
            .split(',');
        
        _polygonPoints = coordsStr.map((coord) {
          final parts = coord.trim().split(' ');
          if (parts.length >= 2) {
            return LatLng(
              double.parse(parts[0]),
              double.parse(parts[1]),
            );
          }
          return null;
        }).whereType<LatLng>().toList();
      }
    } catch (e) {
      // Failed to parse, leave as null
      print('Failed to parse geofence area: $e');
    }
  }

  // Getters
  GeofenceType? get type => _type;
  LatLng? get center => _center;
  double? get radius => _radius;
  List<LatLng>? get polygonPoints => _polygonPoints;

  /// Formatted radius for display
  String get radiusText {
    if (_radius == null) return 'N/A';
    if (_radius! >= 1000) {
      return '${(_radius! / 1000).toStringAsFixed(1)} km';
    }
    return '${_radius!.toStringAsFixed(0)} m';
  }

  /// Icon for geofence type
  String get typeIcon {
    switch (_type) {
      case GeofenceType.circle:
        return '⭕';
      case GeofenceType.polygon:
        return '🔷';
      default:
        return '📍';
    }
  }

  /// Color for geofence (based on status)
  int get colorValue {
    return isActive ? 0xFF2D6A4F : 0xFF9E9E9E; // Green or grey
  }
}

enum GeofenceType {
  circle,
  polygon,
}
