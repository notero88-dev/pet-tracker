// Lazy reverse geocoder with an in-memory LRU-style cache.
//
// Why this exists separately from the inline `placemarkFromCoordinates`
// calls in the Zona de Casa wizard: the home screen renders one pet card
// per device, each card needs a human-readable place name (e.g. "Bella
// Suiza · hace 14 min" rather than "4.679140, -74.052438 · hace 14 min").
// Without a cache, every rebuild would fire a fresh geocoding request
// per card — wasteful and rate-limited on iOS (MapKit caps around 50
// requests/minute per app).
//
// Strategy:
//   - Cache key is the lat/lng rounded to 4 decimal places (~11 m).
//     Two consecutive position updates from the same parked dog round
//     to the same key.
//   - Returns the most specific neighborhood-like name we can find:
//     subLocality (neighborhood) → locality (city) → administrativeArea
//     → null. Caller renders the bare coordinate string if null.
//   - Cache is process-lived; cleared on app restart. No eviction since
//     a typical user has a handful of unique positions per day.
//   - Failures are cached as null so we don't retry forever on areas
//     the geocoder doesn't know.

import 'package:geocoding/geocoding.dart';

class ReverseGeocoder {
  ReverseGeocoder._();
  static final ReverseGeocoder instance = ReverseGeocoder._();

  final Map<String, String?> _cache = {};
  // Track in-flight lookups so concurrent calls for the same key
  // share one network request.
  final Map<String, Future<String?>> _inFlight = {};

  /// Returns the nearest place name for the given coordinates, or null
  /// if the geocoder has nothing useful. Result is cached.
  Future<String?> nearestPlace(double lat, double lng) async {
    final key = _cacheKey(lat, lng);
    if (_cache.containsKey(key)) return _cache[key];
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = _lookup(lat, lng, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<String?> _lookup(double lat, double lng, String key) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        _cache[key] = null;
        return null;
      }
      final p = placemarks.first;
      final name = _bestName(p);
      _cache[key] = name;
      return name;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }

  /// Pick the most specific place name from a Placemark.
  /// In Bogotá this typically returns the barrio ("Bella Suiza",
  /// "Chapinero", "El Chicó") via subLocality. Other cities may put the
  /// neighborhood in `subAdministrativeArea` or `locality`; we try them
  /// in order of specificity.
  String? _bestName(Placemark p) {
    final candidates = <String?>[
      p.subLocality,
      p.subAdministrativeArea,
      p.locality,
      p.administrativeArea,
      p.name,
    ];
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c.trim();
    }
    return null;
  }

  String _cacheKey(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
}
