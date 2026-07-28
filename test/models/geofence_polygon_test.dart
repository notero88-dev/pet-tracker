// Round-trip guard for free-form (polygon) safe zones (2026-07-28).
//
// The create screen writes `POLYGON ((lat lon, lat lon, ...))` and the
// Geofence model must parse that exact string back into the same points —
// otherwise a zone the user just drew would render wrong (or not at all)
// on the pet map and in the edit screen. The circle WKT had exactly this
// class of silent mismatch bug in May 2026 (degrees-vs-meters, paren
// spacing), so polygons get a regression test from day one.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:pettrack_app/models/geofence.dart';

void main() {
  group('Geofence polygon WKT parsing', () {
    test('parses the exact format the app writes (create screen/provider)',
        () {
      // Same construction as _buildWKT / createPolygonGeofence.
      final points = [
        const LatLng(4.679, -74.052),
        const LatLng(4.680, -74.051),
        const LatLng(4.681, -74.053),
        const LatLng(4.679, -74.054),
      ];
      final coords =
          points.map((p) => '${p.latitude} ${p.longitude}').join(', ');
      final g = Geofence(
        id: 1,
        name: 'Finca',
        area: 'POLYGON (($coords))',
        createdAt: DateTime(2026, 7, 28),
      );

      expect(g.type, GeofenceType.polygon);
      expect(g.polygonPoints, isNotNull);
      expect(g.polygonPoints!.length, points.length);
      for (var i = 0; i < points.length; i++) {
        expect(g.polygonPoints![i].latitude, closeTo(points[i].latitude, 1e-9));
        expect(
            g.polygonPoints![i].longitude, closeTo(points[i].longitude, 1e-9));
      }
    });

    test('parses Traccar\'s no-space variant "POLYGON((...))"', () {
      final g = Geofence(
        id: 2,
        name: 'Finca',
        area: 'POLYGON((4.67 -74.05, 4.68 -74.05, 4.68 -74.04))',
        createdAt: DateTime(2026, 7, 28),
      );
      expect(g.type, GeofenceType.polygon);
      expect(g.polygonPoints!.length, 3);
      expect(g.polygonPoints!.first.latitude, closeTo(4.67, 1e-9));
      expect(g.polygonPoints!.last.longitude, closeTo(-74.04, 1e-9));
    });

    test('circle WKT still parses (no regression from polygon support)', () {
      final g = Geofence(
        id: 3,
        name: 'Casa',
        area: 'CIRCLE (4.679186 -74.052371, 70)',
        createdAt: DateTime(2026, 7, 28),
      );
      expect(g.type, GeofenceType.circle);
      expect(g.center!.latitude, closeTo(4.679186, 1e-9));
      expect(g.radius, 70);
    });
  });
}
