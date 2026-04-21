import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/device.dart';

/// Client for PetTrack Provisioning API
class ProvisioningApi {
  final String baseUrl = AppConstants.provisioningApiUrl;
  
  // Production API key (from backend deployment)
  static const String _apiKey = 'pt_prod_427cce864697e6469353e02b9495e32427e266033f93049c54b26ef632a71c92';

  /// Get headers with API key
  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      'x-api-key': _apiKey,
    };
  }

  /// Provision a new device (creates Traccar device + business DB entry)
  /// 
  /// POST /provision
  /// Body: {
  ///   "email": "user@example.com",
  ///   "phone": "+573001234567",
  ///   "deviceImei": "867284062538543",
  ///   "petName": "Firulais"
  /// }
  /// 
  /// Returns: Device object with traccarId
  Future<Device> provisionDevice({
    required String imei,
    required String name,
    required String userId,
    required String userEmail,
    required String petName,
    required String petType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/provision'),
        headers: _headers,
        body: jsonEncode({
          'email': userEmail,
          'phone': '', // Optional phone number
          'deviceImei': imei,
          'petName': petName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Backend returns: { success, userId, deviceId, message, credentials }
        if (data['success'] == true && data['deviceId'] != null) {
          // Store credentials for future use (returned via exception/callback)
          // Note: Credentials are in data['credentials'] = { email, password }
          _lastProvisionedCredentials = data['credentials'];
          
          // Construct Device object from response
          return Device(
            id: data['deviceId'], // Use Traccar device ID as primary ID
            name: name,
            uniqueId: imei,
            traccarId: data['deviceId'],
            status: 'active',
            createdAt: DateTime.now(),
            lastUpdate: null,
            lastLocation: null,
          );
        } else {
          throw Exception(data['message'] ?? 'Error al aprovisionar dispositivo');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? error['message'] ?? 'Error al aprovisionar dispositivo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
  
  // Temporary storage for last provisioned credentials
  Map<String, dynamic>? _lastProvisionedCredentials;
  
  /// Get last provisioned credentials (email + password)
  Map<String, dynamic>? getLastProvisionedCredentials() {
    return _lastProvisionedCredentials;
  }

  /// Get device status and last position
  /// 
  /// GET /device-status/:deviceId
  /// 
  /// Returns: {
  ///   "traccarDevice": {...},
  ///   "lastPosition": {...} or null,
  ///   "online": true/false
  /// }
  Future<Map<String, dynamic>> getDeviceStatus(int traccarDeviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/device-status/$traccarDeviceId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al obtener estado del dispositivo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Send command to device (e.g., locate now, set interval)
  /// 
  /// POST /send-command/:deviceId
  /// Body: {
  ///   "type": "positionSingle" | "setUpdateInterval",
  ///   "attributes": {...} // command-specific data
  /// }
  /// 
  /// Returns: { "success": true, "commandId": 123 }
  Future<Map<String, dynamic>> sendCommand({
    required int traccarDeviceId,
    required String type,
    Map<String, dynamic>? attributes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-command/$traccarDeviceId'),
        headers: _headers,
        body: jsonEncode({
          'type': type,
          'attributes': attributes ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al enviar comando');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Request immediate GPS position
  Future<void> requestPosition(int traccarDeviceId) async {
    await sendCommand(
      traccarDeviceId: traccarDeviceId,
      type: 'positionSingle',
    );
  }

  /// Set update interval (seconds)
  Future<void> setUpdateInterval(int traccarDeviceId, int seconds) async {
    await sendCommand(
      traccarDeviceId: traccarDeviceId,
      type: 'setUpdateInterval',
      attributes: {'interval': seconds},
    );
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
