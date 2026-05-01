import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/device.dart';
import 'wizard_step_result.dart';

/// Client for PetTrack Provisioning API
class ProvisioningApi {
  final String baseUrl = AppConstants.provisioningApiUrl;
  final http.Client _http;

  // Production API key (from backend deployment)
  static const String _apiKey = 'pt_prod_427cce864697e6469353e02b9495e32427e266033f93049c54b26ef632a71c92';

  ProvisioningApi({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

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
    String? phone,
  }) async {
    try {
      // Backend validation rejects empty/missing phone. If the user didn't
      // provide one, send a placeholder so provisioning succeeds; they can
      // update it later from the profile screen.
      final phoneToSend = (phone != null && phone.isNotEmpty)
          ? phone
          : '+573000000000';

      final response = await http.post(
        Uri.parse('$baseUrl/provision'),
        headers: _headers,
        body: jsonEncode({
          'email': userEmail,
          'phone': phoneToSend,
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

  // ---------------------------------------------------------------------------
  // Mode 8 onboarding wizard — driving the device through the manual setup
  // sequence (SCAN → AP → GEO → MODE,8) over TCP. Each call uses
  // `?via=tcp&queue=true&queueMs=N` so a brief device-offline window is
  // absorbed transparently rather than failing the wizard. See:
  //   docs/superpowers/plans/2026-04-29-mode8-flutter-wizard.md
  // ---------------------------------------------------------------------------

  /// Internal helper for the wizard's command endpoints. Sends the request,
  /// maps every HTTP outcome to a WizardStepResult, and never throws on
  /// transport errors — the wizard UI cares about state, not stack traces.
  Future<WizardStepResult> _runWizardCommand({
    required String imei,
    required String pathSuffix,
    required Map<String, dynamic> body,
    int queueMs = 60000,
  }) async {
    final uri = Uri.parse('$baseUrl/devices/$imei/$pathSuffix').replace(
      queryParameters: {
        'via': 'tcp',
        'queue': 'true',
        'queueMs': queueMs.toString(),
      },
    );
    try {
      final res = await _http.post(uri, headers: _headers, body: jsonEncode(body));
      Map<String, dynamic> json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return WizardStepFailed(
          'Malformed response from gateway',
          statusCode: res.statusCode,
        );
      }

      switch (res.statusCode) {
        case 200:
          if (json['success'] == true && json['reply'] is Map) {
            final reply = json['reply'] as Map;
            return WizardStepOk((reply['payload'] ?? '').toString());
          }
          return WizardStepFailed(
            (json['error'] ?? 'unexpected 200 body').toString(),
            statusCode: 200,
          );
        case 408:
          final ttl = (json['queueTtlMs'] is int) ? json['queueTtlMs'] as int : queueMs;
          return WizardStepQueueExpired(ttl);
        case 503:
          return const WizardStepDeviceOffline();
        case 504:
          return const WizardStepTimedOut();
        case 502:
          return WizardStepDeviceRejected((json['payload'] ?? '').toString());
        default:
          return WizardStepFailed(
            (json['error'] ?? 'gateway error').toString(),
            statusCode: res.statusCode,
          );
      }
    } catch (e) {
      return WizardStepFailed('Network error: $e');
    }
  }

  /// Wizard step 1 — ask the device to scan nearby WiFi APs and return them
  /// sorted by RSSI. Reply payload is a comma-separated list of MAC:RSSI
  /// pairs (firmware quirk: V2.1.8 sometimes returns empty — caller should
  /// fall back to placeholder MACs and rely on GPS-only home detection).
  Future<WizardStepResult> scan({
    required String imei,
    int queueMs = 60000,
  }) async {
    return _runWizardCommand(
      imei: imei,
      pathSuffix: 'scan',
      body: const {},
      queueMs: queueMs,
    );
  }

  /// Wizard step 2 — register the 3 home-anchor WiFi MAC addresses on the
  /// device. Backend validates MAC format (12-hex, optional `:` or `-`
  /// separators); device replies `AP,OK` on success.
  Future<WizardStepResult> setAccessPoints({
    required String imei,
    required String mac1,
    required String mac2,
    required String mac3,
    int queueMs = 60000,
  }) async {
    return _runWizardCommand(
      imei: imei,
      pathSuffix: 'access-points',
      body: {'mac1': mac1, 'mac2': mac2, 'mac3': mac3},
      queueMs: queueMs,
    );
  }

  /// Wizard step 3 — set the home geofence center to explicit coordinates.
  /// Used in place of `searchHomeZone` because we already know the user's
  /// chosen location from the map screen, and SEARCH is unreliable on
  /// V2.1.8 firmware (see PLAN.md Epic 3).
  Future<WizardStepResult> setGeoFence({
    required String imei,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    int queueMs = 60000,
  }) async {
    return _runWizardCommand(
      imei: imei,
      pathSuffix: 'geo-fence',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      },
      queueMs: queueMs,
    );
  }

  /// Wizard step 4 — enable Mode 8 ("Home Mode") with a wake-window of T
  /// seconds. Per Mictrack, T must be 10..60. Sends synchronously over
  /// TCP; device replies `MODE,OK` once applied.
  Future<WizardStepResult> setModeHome({
    required String imei,
    required int intervalSeconds,
    int queueMs = 60000,
  }) async {
    if (intervalSeconds < 10 || intervalSeconds > 60) {
      throw ArgumentError(
          'intervalSeconds must be 10..60 for Mode 8, got $intervalSeconds');
    }
    return _runWizardCommand(
      imei: imei,
      pathSuffix: 'mode',
      body: {'type': 'home', 'intervalSeconds': intervalSeconds},
      queueMs: queueMs,
    );
  }

  // ---------------------------------------------------------------------------
  // Home-setup intent — Phase 1 reconciler. Replaces the imperative 4-call
  // wizard above with a desired-state contract: post intent, navigate away,
  // poll status. The four wizard methods above are kept for back-compat
  // (the inline runner inside provisioning-api still uses them) and will be
  // marked deprecated in Phase 3.
  //
  // See pettrack-backend/docs/plans/2026-04-30-home-setup-reconciler.md.
  // ---------------------------------------------------------------------------

  /// Capture the user's home-setup intent. Returns immediately with 202;
  /// reconciliation runs server-side. Poll [getHomeSetupIntent] for status.
  ///
  /// `intentId` is the idempotency key — generate once with `Uuid().v4()` and
  /// reuse on retry. Posting the same intentId twice with the same body is
  /// safe; with a different body returns 409.
  Future<HomeSetupIntent> postHomeSetup({
    required String imei,
    required String intentId,
    required double homeLat,
    required double homeLng,
    required int radiusMeters,
    required String petName,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/devices/$imei/home-setup'),
      headers: _headers,
      body: jsonEncode({
        'intentId': intentId,
        'homeLat': homeLat,
        'homeLng': homeLng,
        'radiusMeters': radiusMeters,
        'petName': petName,
      }),
    );
    final json = _decodeOrThrow(res, op: 'postHomeSetup');
    return HomeSetupIntent.fromJson(json['intent'] as Map<String, dynamic>);
  }

  /// Read the current state of an intent. Returns null on 404 (the intent
  /// row was reaped or the imei/intentId don't match).
  Future<HomeSetupIntent?> getHomeSetupIntent({
    required String imei,
    required String intentId,
  }) async {
    final res = await _http.get(
      Uri.parse('$baseUrl/devices/$imei/home-setup/$intentId'),
      headers: _headers,
    );
    if (res.statusCode == 404) return null;
    final json = _decodeOrThrow(res, op: 'getHomeSetupIntent');
    return HomeSetupIntent.fromJson(json['intent'] as Map<String, dynamic>);
  }

  /// Cancel an in-flight intent. Phase 1 just flips status to cancelled;
  /// Phase 3 will fire explicit rollback (MODE,1,60 + AP,,,) on the device.
  Future<HomeSetupIntent?> cancelHomeSetup({
    required String imei,
    required String intentId,
  }) async {
    final res = await _http.delete(
      Uri.parse('$baseUrl/devices/$imei/home-setup/$intentId'),
      headers: _headers,
    );
    if (res.statusCode == 404 || res.statusCode == 409) return null;
    final json = _decodeOrThrow(res, op: 'cancelHomeSetup');
    return HomeSetupIntent.fromJson(json['intent'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _decodeOrThrow(http.Response res, {required String op}) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw HomeSetupApiException(
        'Malformed response',
        statusCode: res.statusCode,
        op: op,
      );
    }
    if (res.statusCode == 200 || res.statusCode == 202) return json;
    throw HomeSetupApiException(
      (json['error'] ?? 'unknown error').toString(),
      statusCode: res.statusCode,
      op: op,
    );
  }
}

/// One row from device_desired_state, as returned by the home-setup API.
class HomeSetupIntent {
  final String intentId;
  final String imei;
  final int intentVersion;
  final String status; // pending | reconciling | configured | failed | cancelled | superseded
  final String? step; // scan | ap | geo | mode | null when terminal
  final double targetLat;
  final double targetLng;
  final int targetRadiusM;
  final List<String>? targetMacs;
  final String? petName;
  final int attempts;
  final String? lastError;
  final String? supersededBy;
  final DateTime requestedAt;
  final DateTime updatedAt;
  final int elapsedSeconds;

  HomeSetupIntent({
    required this.intentId,
    required this.imei,
    required this.intentVersion,
    required this.status,
    required this.step,
    required this.targetLat,
    required this.targetLng,
    required this.targetRadiusM,
    required this.targetMacs,
    required this.petName,
    required this.attempts,
    required this.lastError,
    required this.supersededBy,
    required this.requestedAt,
    required this.updatedAt,
    required this.elapsedSeconds,
  });

  bool get isTerminal => const {
        'configured', 'verified', 'failed', 'cancelled', 'superseded',
      }.contains(status);

  bool get isSuccess =>
      status == 'configured' || status == 'verified';

  factory HomeSetupIntent.fromJson(Map<String, dynamic> j) {
    return HomeSetupIntent(
      intentId: j['intentId'] as String,
      imei: j['imei'] as String,
      intentVersion: (j['intentVersion'] as num).toInt(),
      status: j['status'] as String,
      step: j['step'] as String?,
      targetLat: (j['targetLat'] as num).toDouble(),
      targetLng: (j['targetLng'] as num).toDouble(),
      targetRadiusM: (j['targetRadiusM'] as num).toInt(),
      targetMacs: (j['targetMacs'] as List?)?.cast<String>(),
      petName: j['petName'] as String?,
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      lastError: j['lastError'] as String?,
      supersededBy: j['supersededBy'] as String?,
      requestedAt: DateTime.parse(j['requestedAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      elapsedSeconds: (j['elapsedSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class HomeSetupApiException implements Exception {
  final String message;
  final int statusCode;
  final String op;
  HomeSetupApiException(this.message, {required this.statusCode, required this.op});
  @override
  String toString() => 'HomeSetupApiException($op, $statusCode): $message';
}
