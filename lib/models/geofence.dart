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

  /// Parse Traccar's WKT area format.
  ///
  /// Traccar emits geofences in WKT-like strings. Two flavors land here:
  ///
  ///   CIRCLE (lat lon, radius_meters)
  ///       e.g. "CIRCLE (4.679186 -74.052371, 70)"
  ///       (note the space after CIRCLE and the comma before radius —
  ///       this is the format the live droplet returns as of 2026-05-19)
  ///   POLYGON ((lat1 lon1, lat2 lon2, ...))
  ///       e.g. "POLYGON ((4.67 -74.05, 4.68 -74.05, 4.68 -74.04, ...))"
  ///
  /// 2026-05-19 bug-fix history (was failing silently in production):
  ///
  ///   1. Old parser did `substring(7, …).split(' ')` assuming
  ///      "CIRCLE(...)" (no space). The actual "CIRCLE (...)" left
  ///      `coords[0] = "(4.679186"` and `double.parse` threw on the
  ///      leading paren — caught by the outer try/catch, both
  ///      `_center` and `_radius` stayed null, `_isInHomeZone` returned
  ///      false, "En casa" never displayed. Nico's 2026-05-19 14:02 PM
  ///      device log line-for-line surfaced the bug:
  ///          type=GeofenceType.circle  center=null  radius=null
  ///          raw_area="CIRCLE (4.679186 -74.052371, 70)"
  ///   2. Old parser also did `radiusDegrees * 111000` assuming
  ///      Traccar emitted degrees. Traccar actually emits meters —
  ///      the multiplier would have turned a 70 m zone into a
  ///      7 770 km circle (bigger than Colombia).
  ///
  /// Robust strategy now: pull everything between the FIRST '(' and
  /// the LAST ')', then split on any run of commas-or-whitespace and
  /// read the first 3 tokens as (lat, lon, radius_m). Works for
  /// "CIRCLE(...)", "CIRCLE (...)", trailing spaces, and any
  /// reasonable variation. Polygon path mirrors the same idea.
  void _parseArea() {
    try {
      if (area.startsWith('CIRCLE')) {
        _type = GeofenceType.circle;

        final openParen = area.indexOf('(');
        final closeParen = area.lastIndexOf(')');
        if (openParen < 0 || closeParen <= openParen) return;

        final inner = area.substring(openParen + 1, closeParen);
        final parts = inner
            .split(RegExp(r'[,\s]+'))
            .where((p) => p.isNotEmpty)
            .toList();

        if (parts.length >= 3) {
          final lat = double.parse(parts[0]);
          final lon = double.parse(parts[1]);
          final radiusMeters = double.parse(parts[2]);
          _center = LatLng(lat, lon);
          _radius = radiusMeters; // Traccar emits meters directly.
        }
      } else if (area.startsWith('POLYGON')) {
        _type = GeofenceType.polygon;

        // Pull contents between the OUTER "((" and "))".
        final openParen = area.indexOf('((');
        final closeParen = area.lastIndexOf('))');
        if (openParen < 0 || closeParen <= openParen) return;

        final inner = area.substring(openParen + 2, closeParen);

        _polygonPoints = inner.split(',').map((coord) {
          final parts = coord
              .trim()
              .split(RegExp(r'\s+'))
              .where((p) => p.isNotEmpty)
              .toList();
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
      // ignore: avoid_print
      print('Geofence: failed to parse area "$area": $e');
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
