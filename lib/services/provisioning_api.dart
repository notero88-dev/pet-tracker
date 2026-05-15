import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/device.dart';
import 'wizard_step_result.dart';

/// Client for PetTrack Provisioning API
class ProvisioningApi {
  final String baseUrl = AppConstants.provisioningApiUrl;
  final http.Client _http;

  ProvisioningApi({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Build auth headers. Async because we have to ask Firebase for a
  /// fresh ID token (it's auto-refreshed by the SDK; we don't cache).
  ///
  /// Phase C (2026-05-13): backend now requires `Authorization: Bearer
  /// [firebase_id_token]`. The legacy `x-api-key` path was removed
  /// from this client and rotated on the server simultaneously. If
  /// `getIdToken()` returns null (user not signed in), the request
  /// will 401 on the server — which is the correct behavior since
  /// every endpoint here requires an authenticated user.
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Token fetch failed. Send no Authorization header; server 401s.
      // Caller decides whether to retry / re-auth.
    }
    return headers;
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
        headers: await _authHeaders(),
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
  
  /// Register the user's Firebase Cloud Messaging token with the
  /// provisioning-api so push-service can fan out geofence-exit /
  /// alarm notifications via FCM. Returns `true` on success.
  ///
  /// The token also gets written to Firestore via FirestoreService;
  /// the postgres mirror here is what push-service queries (Firestore
  /// is the app's own read path). Both writes are best-effort —
  /// either can fail without blocking the other.
  ///
  /// 404 from the API means the customer row hasn't been mirrored yet
  /// (legacy account or pre-/provision install). Skip silently; the
  /// next /provision call creates the row and the next token refresh
  /// will land it.
  Future<bool> registerFcmToken({
    required String email,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: await _authHeaders(),
        body: jsonEncode({'email': email, 'token': token}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return true;
      }
      // ignore: avoid_print
      print('registerFcmToken: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('registerFcmToken failed: $e');
      return false;
    }
  }

  /// Delete the currently-signed-in user's account server-side.
  ///
  /// Triggered from the Cuenta → Eliminar cuenta flow (Apple App Store
  /// Guideline 5.1.1(v) — accounts must be deletable from inside the
  /// app). The backend cascades: soft-deletes Postgres customer + pets
  /// + geofences, cancels subscriptions, hard-deletes the Traccar user
  /// (releases the device), and hard-deletes the Firebase Auth user.
  ///
  /// After this returns true the client should sign out — the Firebase
  /// session is invalid anyway because the user was deleted.
  ///
  /// Returns false on any non-200; caller surfaces an error toast.
  Future<bool> deleteAccount() async {
    try {
      final response = await _http.delete(
        Uri.parse('$baseUrl/users/me'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        return true;
      }
      // ignore: avoid_print
      print('deleteAccount: HTTP ${response.statusCode} body=${response.body}');
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('deleteAccount failed: $e');
      return false;
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
        headers: await _authHeaders(),
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
        headers: await _authHeaders(),
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
  // sequence (SCAN → AP → GEO → MODE,8). Originally hardcoded to TCP, but
  // production default is `DEFAULT_COMMAND_TRANSPORT=sms` because Claro 2G
  // CGNAT blackholes inbound TCP for our Hologram SIMs in Colombia (see
  // pettrack-backend/docs/COMMAND-TRANSPORT.md). We now omit `via=` and let
  // the backend pick — TCP if it ever comes back, SMS today. The app stays
  // transport-agnostic, which is the whole point of the design.
  //
  // We keep `queue=true&queueMs=N` for the TCP path's brief-offline window;
  // the SMS path ignores those query params (Hologram queues at the carrier).
  // ---------------------------------------------------------------------------

  /// Internal helper for the wizard's command endpoints. Sends the request,
  /// maps every HTTP outcome to a WizardStepResult, and never throws on
  /// transport errors — the wizard UI cares about state, not stack traces.
  Future<WizardStepResult> _runWizardCommand({
    required String imei,
    required String pathSuffix,
    required Map<String, dynamic> body,
    int queueMs = 14400000,  // 4h, matches server default (raised 2026-05-06 per Mictrack vendor confirmation)
  }) async {
    final uri = Uri.parse('$baseUrl/devices/$imei/$pathSuffix').replace(
      queryParameters: {
        // No 'via' — let backend pick based on DEFAULT_COMMAND_TRANSPORT.
        'queue': 'true',
        'queueMs': queueMs.toString(),
      },
    );
    try {
      // ignore: avoid_print
      print('[Wizard] POST $uri body=${jsonEncode(body)}');
      final res = await _http.post(uri, headers: await _authHeaders(), body: jsonEncode(body));
      // ignore: avoid_print
      print('[Wizard] <- ${res.statusCode} body=${res.body}');
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
        case 202:
          // 2026-05-15 — gateway parked the command for offline-reconnect.
          // The command will eventually fire when the device wakes; the
          // caller updates UI to "Esperando..." and waits for an FCM
          // `command_completed` push (or polls /state). See KANBAN row
          // tracking the "En vivo Bad file descriptor" fix.
          if (json['success'] == true && json['status'] == 'queued') {
            return WizardStepQueued(
              queueId: json['queueId'] is int
                  ? json['queueId'] as int
                  : int.tryParse('${json['queueId']}'),
              ttlMs: json['ttlMs'] is int
                  ? json['ttlMs'] as int
                  : queueMs,
            );
          }
          return WizardStepFailed(
            (json['error'] ?? 'unexpected 202 body').toString(),
            statusCode: 202,
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
    int queueMs = 14400000,  // 4h, matches server default (raised 2026-05-06 per Mictrack vendor confirmation)
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
    int queueMs = 14400000,  // 4h, matches server default (raised 2026-05-06 per Mictrack vendor confirmation)
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
    int queueMs = 14400000,  // 4h, matches server default (raised 2026-05-06 per Mictrack vendor confirmation)
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
    int queueMs = 14400000,  // 4h, matches server default (raised 2026-05-06 per Mictrack vendor confirmation)
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

  /// "Pet is lost" / search mode — flips the device into Mode 1 (real-time
  /// reporting, always-on TCP, no motion gating). Burns battery FAST: a
  /// fully-charged Petti drops to ~10-20% within 24h on Mode 1 with T=30s.
  /// Pair with a UX warning before enabling and a clear "back to normal"
  /// affordance to restore Mode 8 once the pet is found.
  ///
  /// Per Mictrack protocol PDF §3.3.1, Mode 1 T range is [10,600] seconds.
  /// We default to 30s — same cadence as Mode 8 outdoor — to keep the
  /// position-stream UX consistent across the two modes.
  ///
  /// **Deprecated 2026-05-13 — use [lockMode] for the "Buscar a [pet]"
  /// flow.** Mode 1 is permanent until manually reverted, which means a
  /// forgotten "Buscar" session drains the battery overnight. LOCK is a
  /// time-bounded overlay that auto-reverts to the device's previous mode
  /// after [revertMinutes], so a panicked tap → forgot doesn't kill the
  /// device. Kept here for back-compat with code paths that still call it
  /// (e.g. tests, debug screens) until those migrate.
  Future<WizardStepResult> setModeRealtime({
    required String imei,
    int intervalSeconds = 30,
    int queueMs = 14400000,  // 4h, matches server default (raised 2026-05-06 per Mictrack vendor confirmation)
  }) async {
    if (intervalSeconds < 10 || intervalSeconds > 600) {
      throw ArgumentError(
          'intervalSeconds must be 10..600 for Mode 1, got $intervalSeconds');
    }
    return _runWizardCommand(
      imei: imei,
      pathSuffix: 'mode',
      body: {'type': 'realtime', 'intervalSeconds': intervalSeconds},
      queueMs: queueMs,
    );
  }

  /// LIVE mode — temporary "Buscar a [pet]" override.
  ///
  /// Sends `LOCK,intervalSeconds,revertMinutes` to the device. The device
  /// streams positions at [intervalSeconds] for [revertMinutes], then
  /// auto-reverts to its previous persistent mode (Mode 8 HOME or Mode 7
  /// AWAY). No server-side timer needed — the device handles the revert
  /// itself per Mictrack PDF p.1.
  ///
  /// This is the recommended replacement for [setModeRealtime] in the
  /// "Pet is lost" UX. Unlike Mode 1 (which is permanent), LOCK can't
  /// silently drain the battery if the user forgets to switch back.
  ///
  /// Vendor ranges (Mictrack_MT710_Commands_List.pdf p.1):
  ///   intervalSeconds 10..60, revertMinutes 1..60.
  Future<WizardStepResult> lockMode({
    required String imei,
    int intervalSeconds = 10,
    int revertMinutes = 5,
    int queueMs = 14400000,
  }) async {
    if (intervalSeconds < 10 || intervalSeconds > 60) {
      throw ArgumentError(
          'intervalSeconds must be 10..60 for LOCK, got $intervalSeconds');
    }
    if (revertMinutes < 1 || revertMinutes > 60) {
      throw ArgumentError(
          'revertMinutes must be 1..60 for LOCK, got $revertMinutes');
    }
    return _runWizardCommand(
      imei: imei,
      pathSuffix: 'lock',
      body: {
        'intervalSeconds': intervalSeconds,
        'revertMinutes': revertMinutes,
      },
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
    // Phase B (2026-05-11): optional phone-side fields. When the app
    // supplies homeBssid, the runner skips the on-device SCAN and uses
    // this BSSID for the AP slot directly. Both must be supplied
    // together (or both omitted) — the backend validates this.
    String? homeBssid,
    String? homeSsid,
  }) async {
    final body = <String, dynamic>{
      'intentId': intentId,
      'homeLat': homeLat,
      'homeLng': homeLng,
      'radiusMeters': radiusMeters,
      'petName': petName,
    };
    if (homeBssid != null) body['homeBssid'] = homeBssid;
    if (homeSsid != null) body['homeSsid'] = homeSsid;
    final res = await _http.post(
      Uri.parse('$baseUrl/devices/$imei/home-setup'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    final json = _decodeOrThrow(res, op: 'postHomeSetup');
    return HomeSetupIntent.fromJson(json['intent'] as Map<String, dynamic>);
  }

  /// Look up the most-recent active intent for an IMEI. Returns null when
  /// no active intent exists (the home-screen banner uses this on cold
  /// start so it doesn't have to remember intentId across app restarts).
  Future<HomeSetupIntent?> getActiveHomeSetupIntent({
    required String imei,
  }) async {
    final res = await _http.get(
      Uri.parse('$baseUrl/devices/$imei/home-setup'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 404) return null;
    final json = _decodeOrThrow(res, op: 'getActiveHomeSetupIntent');
    return HomeSetupIntent.fromJson(json['intent'] as Map<String, dynamic>);
  }

  /// Look up the most-recent intent for an IMEI regardless of status.
  /// Used by the Settings entry card to decide between the configured
  /// and unconfigured variants. The caller checks the returned
  /// `intent.status` to differentiate configured/reconciling/failed.
  /// Returns null when no intent has ever been created for this IMEI.
  Future<HomeSetupIntent?> getLatestHomeSetupIntent({
    required String imei,
  }) async {
    final res = await _http.get(
      Uri.parse('$baseUrl/devices/$imei/home-setup/latest'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 404) return null;
    final json = _decodeOrThrow(res, op: 'getLatestHomeSetupIntent');
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
      headers: await _authHeaders(),
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
      headers: await _authHeaders(),
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
  // Phase B (2026-05-11): phone-side home-zone fields. setupMethod is
  // 'phone_scan' for new intents that captured BSSID on the phone,
  // 'device_scan' for legacy ones that ran SCAN on the MT710.
  // homeSsid is what the settings screen shows ("Casa configurada:
  // Corporativo Habi") and homeBssid is what was actually programmed
  // into the device's AP slot.
  final String? homeBssid;
  final String? homeSsid;
  final String setupMethod;
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
    this.homeBssid,
    this.homeSsid,
    this.setupMethod = 'device_scan',
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
      // Phase B fields — older intents won't have them, so default safely.
      homeBssid: j['homeBssid'] as String?,
      homeSsid: j['homeSsid'] as String?,
      setupMethod: (j['setupMethod'] as String?) ?? 'device_scan',
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
