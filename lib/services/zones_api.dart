// Thin HTTP client for the atomic safe-zone endpoints on the
// provisioning-api (zonesRoutes.js). Replaces the app's old two-call
// path straight to Traccar (create geofence + link from the phone),
// which could drop the link on any mid-flight failure and still look
// successful — see docs/plans/2026-07-28-zonas-bugs-plan.md (Lote 1)
// in the backend repo.
//
// Contract: a 2xx from these endpoints means the zone EXISTS, is
// LINKED to the collar, and has its Postgres mirror row — i.e. it can
// actually fire enter/exit alerts. Any error here must surface to the
// user with a retry; never show success on failure.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

class ZoneApiException implements Exception {
  final int? statusCode;
  final String message;
  ZoneApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ZoneApiException($statusCode): $message';
}

class ZonesApi {
  final String baseUrl;
  final http.Client _client;

  ZonesApi({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.provisioningApiUrl,
        _client = client ?? http.Client();

  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Token fetch failed — server 401s and we surface the error.
    }
    return headers;
  }

  Map<String, dynamic> _circleBody(
      String name, double lat, double lng, double radiusMeters) {
    return {
      'name': name,
      'shape': 'circle',
      'latitude': lat,
      'longitude': lng,
      'radiusMeters': radiusMeters,
    };
  }

  Map<String, dynamic> _polygonBody(String name, List<LatLng> points) {
    return {
      'name': name,
      'shape': 'polygon',
      'points': [
        for (final p in points) {'lat': p.latitude, 'lng': p.longitude},
      ],
    };
  }

  /// List this pet's zones (Lote 3.5). The server lists from the
  /// Postgres mirror — the row that decides whether an alert can fire —
  /// scoped to THIS device's pet. The app used to read the account's
  /// whole Traccar geofence set and filter on `deviceId == null`, but
  /// Traccar's geofence JSON has no deviceId so that matched every
  /// zone: with two pets, pet A's zones drew on pet B's map and the
  /// 3-zone limit counted them all.
  ///
  /// `area` may be null when Traccar is unreachable; callers should
  /// fall back to the circle fields so the list still renders.
  Future<List<Map<String, dynamic>>> listZones({required String imei}) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/devices/$imei/zones'),
            headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    final json = _decode(res);
    if (res.statusCode == 200 && json?['success'] == true) {
      final zones = json?['zones'];
      if (zones is List) return zones.whereType<Map<String, dynamic>>().toList();
      return const [];
    }
    throw ZoneApiException(
      _errorMessage(json, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  /// Create a zone. Returns the Traccar geofence id on success; throws
  /// [ZoneApiException] on any failure (the server already rolled back).
  Future<int> createZone({
    required String imei,
    required Map<String, dynamic> body,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/devices/$imei/zones'),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final json = _decode(res);
    if (res.statusCode == 201 && json?['success'] == true) {
      final id = json?['zone']?['traccar_geofence_id'];
      if (id is int) return id;
      // Defensive: success without id shouldn't happen; treat as error.
      throw ZoneApiException('Respuesta inesperada del servidor',
          statusCode: res.statusCode);
    }
    throw ZoneApiException(
      _errorMessage(json, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<int> createCircleZone({
    required String imei,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) =>
      createZone(
          imei: imei, body: _circleBody(name, latitude, longitude, radiusMeters));

  Future<int> createPolygonZone({
    required String imei,
    required String name,
    required List<LatLng> points,
  }) =>
      createZone(imei: imei, body: _polygonBody(name, points));

  /// Update in place (server modifies the existing Traccar geofence —
  /// never delete-then-create, so a failure can't lose the zone).
  Future<void> updateZone({
    required String imei,
    required int traccarGeofenceId,
    required Map<String, dynamic> body,
  }) async {
    final res = await _client
        .put(
          Uri.parse('$baseUrl/devices/$imei/zones/$traccarGeofenceId'),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final json = _decode(res);
    if (res.statusCode == 200 && json?['success'] == true) return;
    throw ZoneApiException(
      _errorMessage(json, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<void> updateCircleZone({
    required String imei,
    required int traccarGeofenceId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) =>
      updateZone(
        imei: imei,
        traccarGeofenceId: traccarGeofenceId,
        body: _circleBody(name, latitude, longitude, radiusMeters),
      );

  Future<void> updatePolygonZone({
    required String imei,
    required int traccarGeofenceId,
    required String name,
    required List<LatLng> points,
  }) =>
      updateZone(
        imei: imei,
        traccarGeofenceId: traccarGeofenceId,
        body: _polygonBody(name, points),
      );

  Future<void> deleteZone({
    required String imei,
    required int traccarGeofenceId,
  }) async {
    final res = await _client
        .delete(
          Uri.parse('$baseUrl/devices/$imei/zones/$traccarGeofenceId'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final json = _decode(res);
    if (res.statusCode == 200 && json?['success'] == true) return;
    throw ZoneApiException(
      _errorMessage(json, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Map<String, dynamic>? _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(Map<String, dynamic>? json, int status) {
    final serverMsg = json?['error'];
    if (serverMsg is String && serverMsg.isNotEmpty) return serverMsg;
    if (status == 404) return 'Zona o dispositivo no encontrado';
    if (status == 401) return 'Sesión vencida — vuelve a iniciar sesión';
    return 'No pudimos guardar la zona — inténtalo de nuevo';
  }

  void close() => _client.close();
}
