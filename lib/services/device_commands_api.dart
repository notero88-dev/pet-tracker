// Thin HTTP client for the device command endpoints exposed by
// provisioning-api. The app is **intentionally agnostic** about how those
// commands actually reach the MT710 — that decision lives in the backend.
//
// As of April 2026 the backend default transport is SMS via Hologram (see
// pettrack-backend/docs/COMMAND-TRANSPORT.md). When Hologram enables Cat-M1
// roaming on Movistar Colombia, the backend will switch to direct TCP
// downlink via the mictrack-gateway socket — and this file will not need
// to change.
//
// PLEASE DO NOT add ?via=sms or ?via=tcp here. The whole point of the
// server-side transport selection is that the app never knows. If you find
// yourself wanting to branch on transport, read COMMAND-TRANSPORT.md first
// and consider whether a backend change is the right answer instead.
//
// All methods return a typed result. Expected HTTP codes:
//   200        command succeeded (TCP: device replied OK; SMS: queued at Hologram)
//   400        our payload is malformed
//   503        device is not currently connected (TCP path) / no IMEI mapping (SMS path)
//   504        command timed out waiting for device reply (TCP path only)
//   502        device explicitly rejected the command (returned FS) (TCP path only)
//   500 / 5xx  upstream failure
//
// On 200 the response body is { success: true, reply: {...} }. The shape of
// `reply` differs slightly between transports — see COMMAND-TRANSPORT.md
// section "What the Flutter app sees" — but both are safe to treat as
// "command accepted." For SMS the device-side confirmation lands later
// (future work: Hologram inbound webhook, Option B).

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Result shape. Matches the convention used elsewhere in this app.
sealed class DeviceCommandResult {
  const DeviceCommandResult();
}

class DeviceCommandOk extends DeviceCommandResult {
  final Map<String, dynamic> reply;
  const DeviceCommandOk(this.reply);
}

class DeviceCommandError extends DeviceCommandResult {
  final int? statusCode;
  final String message;
  final String? payload;
  const DeviceCommandError({
    required this.message,
    this.statusCode,
    this.payload,
  });

  bool get isOffline => statusCode == 503;
  bool get isTimeout => statusCode == 504;
  bool get isRejectedByDevice => statusCode == 502;
}

/// Tracking mode enum mirroring the provisioning-api's expected body shape.
enum TrackingMode { realtime, home, deepSleep, wifiPriority }

String _modeTypeString(TrackingMode m) {
  switch (m) {
    case TrackingMode.realtime:
      return 'realtime';
    case TrackingMode.home:
      return 'home';
    case TrackingMode.deepSleep:
      return 'deepSleep';
    case TrackingMode.wifiPriority:
      return 'wifiPriority';
  }
}

class DeviceCommandsApi {
  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  DeviceCommandsApi({
    String? baseUrl,
    String? apiKey,
    http.Client? client,
  })  : baseUrl = baseUrl ?? AppConstants.provisioningApiUrl,
        apiKey = apiKey ??
            'pt_prod_427cce864697e6469353e02b9495e32427e266033f93049c54b26ef632a71c92',
        _client = client ?? http.Client();

  // -----------------------------------------------------------------
  // Mode — /devices/:imei/mode
  // -----------------------------------------------------------------

  /// Set tracking mode. Different fields required depending on [mode]:
  ///   realtime        intervalSeconds (10-600)
  ///   home            intervalSeconds (10-60)
  ///   deepSleep       intervalHours (1-24)
  ///   wifiPriority    t1Minutes (10-1440), t2Hours (1-24)
  Future<DeviceCommandResult> setMode({
    required String imei,
    required TrackingMode mode,
    int? intervalSeconds,
    int? intervalHours,
    int? t1Minutes,
    int? t2Hours,
  }) async {
    final body = <String, dynamic>{'type': _modeTypeString(mode)};
    if (intervalSeconds != null) body['intervalSeconds'] = intervalSeconds;
    if (intervalHours != null) body['intervalHours'] = intervalHours;
    if (t1Minutes != null) body['t1Minutes'] = t1Minutes;
    if (t2Hours != null) body['t2Hours'] = t2Hours;

    return _post('/devices/$imei/mode', body);
  }

  // -----------------------------------------------------------------
  // Home Zone — /devices/:imei/home-zone
  // -----------------------------------------------------------------

  Future<DeviceCommandResult> setHomeZone({
    required String imei,
    required int radiusMeters,
  }) =>
      _post('/devices/$imei/home-zone', {'radiusMeters': radiusMeters});

  // -----------------------------------------------------------------
  // Reboot — /devices/:imei/reboot
  // -----------------------------------------------------------------

  Future<DeviceCommandResult> reboot({required String imei}) =>
      _post('/devices/$imei/reboot', {});

  // -----------------------------------------------------------------
  // Is-online probe — /devices/:imei/online
  // -----------------------------------------------------------------

  Future<bool> isOnline(String imei) async {
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/devices/$imei/online'),
        headers: _headers,
      );
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['online'] == true;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      };

  Future<DeviceCommandResult> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 40));

      Map<String, dynamic> json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        json = {};
      }

      if (res.statusCode == 200 && json['success'] == true) {
        return DeviceCommandOk(
          (json['reply'] as Map<String, dynamic>?) ?? {},
        );
      }
      return DeviceCommandError(
        statusCode: res.statusCode,
        message: (json['error'] as String?) ??
            'Error del servidor (${res.statusCode})',
        payload: json['payload'] as String?,
      );
    } catch (e) {
      return DeviceCommandError(
        message: 'Error de conexión: $e',
      );
    }
  }

  void close() => _client.close();
}
