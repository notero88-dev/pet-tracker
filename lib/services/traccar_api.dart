import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/device.dart';
import '../models/position.dart';

/// Client for Traccar REST API
/// 
/// Note: In production, most of these calls should go through our backend proxy
/// for security. For MVP, we're accessing Traccar directly with session auth.
class TraccarApi {
  final String baseUrl = AppConstants.traccarApiUrl;
  String? _sessionCookie;

  /// Login to Traccar and get session cookie
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/session'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'email=$email&password=$password',
      );

      if (response.statusCode == 200) {
        // Extract session cookie
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          _sessionCookie = cookies.split(';')[0];
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Traccar login error: $e');
      return false;
    }
  }

  /// Get headers with session cookie
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
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
    _sessionCookie = null;
  }
}
