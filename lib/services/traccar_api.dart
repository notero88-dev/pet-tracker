import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/device.dart';
import '../models/position.dart';

/// Client for Traccar REST API
///
/// Note: In production, most of these calls should go through our backend proxy
/// for security. For MVP, we're accessing Traccar directly.
///
/// We use **HTTP Basic auth** (Authorization header) instead of session cookies.
/// Why: on Flutter web, browsers hide `Set-Cookie` from JavaScript (security
/// policy) and won't forward cross-origin cookies without `withCredentials=true`
/// + matching CORS on Traccar. Basic auth sidesteps all of that and works
/// identically on iOS/Android/web. See docs/STATUS_2026-04-22.md.
class TraccarApi {
  final String baseUrl = AppConstants.traccarApiUrl;
  String? _authHeader;

  /// Store Basic auth header for subsequent requests.
  /// Note: Traccar 6.x returns 404 on GET /api/session, so we can't use that
  /// endpoint to verify credentials. Instead we just store the header — bad
  /// credentials will surface as 401 on the first real API call (e.g. getDevices).
  Future<bool> login(String email, String password) async {
    _authHeader = 'Basic ${base64Encode(utf8.encode('$email:$password'))}';
    return true;
  }

  /// Get headers with Basic auth
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authHeader != null) {
      headers['Authorization'] = _authHeader!;
    }
    return headers;
  }

  /// Get all devices for current user
  Future<List<Device>> getDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((json) {
          // Convert Traccar device format to our Device model
          return Device(
            id: json['id'],
            name: json['name'],
            uniqueId: json['uniqueId'],
            traccarId: json['id'],
            status: json['status'] ?? 'unknown',
            createdAt: DateTime.now(), // Traccar doesn't return this
            lastUpdate: json['lastUpdate'] != null
                ? DateTime.parse(json['lastUpdate'])
                : null,
          );
        }).toList();
      } else {
        throw Exception('Error al obtener dispositivos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Get device by ID
  Future<Device?> getDevice(int deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices/$deviceId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Device(
          id: json['id'],
          name: json['name'],
          uniqueId: json['uniqueId'],
          traccarId: json['id'],
          status: json['status'] ?? 'unknown',
          createdAt: DateTime.now(),
          lastUpdate: json['lastUpdate'] != null
              ? DateTime.parse(json['lastUpdate'])
              : null,
        );
      }
      return null;
    } catch (e) {
      print('Error getting device: $e');
      return null;
    }
  }

  /// Get last position for a device
  Future<Position?> getLastPosition(int deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/positions?deviceId=$deviceId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isEmpty) return null;
        
        // Get most recent position
        final json = data.first;
        return Position.fromJson(json);
      }
      return null;
    } catch (e) {
      print('Error getting position: $e');
      return null;
    }
  }

  /// Get position history for a device
  /// 
  /// from/to: ISO 8601 datetime strings
  Future<List<Position>> getPositionHistory({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final fromStr = from.toUtc().toIso8601String();
      final toStr = to.toUtc().toIso8601String();
      
      final response = await http.get(
        Uri.parse('$baseUrl/positions?deviceId=$deviceId&from=$fromStr&to=$toStr'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((json) => Position.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting position history: $e');
      return [];
    }
  }

  /// Create geofence
  Future<Map<String, dynamic>?> createGeofence({
    required String name,
    required String area, // WKT format, e.g., "CIRCLE(lat lon radius)"
    Map<String, dynamic>? attributes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/geofences'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'area': area,
          'attributes': attributes ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating geofence: $e');
      return null;
    }
  }

  /// Link geofence to device
  Future<bool> linkGeofenceToDevice(int geofenceId, int deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/permissions'),
        headers: _headers,
        body: jsonEncode({
          'deviceId': deviceId,
          'geofenceId': geofenceId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error linking geofence: $e');
      return false;
    }
  }

  /// Get all geofences for current user
  Future<List<Map<String, dynamic>>> getGeofences() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/geofences'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      print('Error getting geofences: $e');
      return [];
    }
  }

  /// Delete geofence
  Future<bool> deleteGeofence(int geofenceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/geofences/$geofenceId'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting geofence: $e');
      return false;
    }
  }

  /// Send command to device
  Future<bool> sendCommand({
    required int deviceId,
    required String type,
    Map<String, dynamic>? attributes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/commands/send'),
        headers: _headers,
        body: jsonEncode({
          'deviceId': deviceId,
          'type': type,
          'attributes': attributes ?? {},
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending command: $e');
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/session'),
        headers: _headers,
      );
    } catch (e) {
      print('Logout error: $e');
    }
    _authHeader = null;
  }
}
