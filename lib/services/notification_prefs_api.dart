// Client for GET/PUT /notification-prefs on the provisioning-api
// (Lote 2.1 — backend PR makes push-service respect these). Before
// this, the toggles lived only in SharedPreferences and the server
// sent every push regardless.
//
// Mapping notes:
//   - Server stores DND times as minutes-from-midnight America/Bogota;
//     the app's TimeOfDay is the user's wall clock, which for our
//     Colombia-only audience is the same thing. No tz conversion.
//   - soundEnabled / vibrationEnabled are DEVICE-side concerns (how a
//     received push is presented) — they stay local-only on purpose.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:http/http.dart' as http;

import '../providers/notification_provider.dart';
import '../utils/constants.dart';

class NotificationPrefsApi {
  final String baseUrl;
  final http.Client _client;

  NotificationPrefsApi({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.provisioningApiUrl,
        _client = client ?? http.Client();

  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  static int? _toMinutes(TimeOfDay? t) =>
      t == null ? null : t.hour * 60 + t.minute;

  static TimeOfDay? _fromMinutes(dynamic m) => m is int
      ? TimeOfDay(hour: m ~/ 60, minute: m % 60)
      : null;

  Map<String, dynamic> _toServerJson(NotificationSettings s) => {
        'geofenceEnter': s.geofenceEnterEnabled,
        'geofenceExit': s.geofenceExitEnabled,
        'batteryLow': s.batteryLowEnabled,
        'deviceOffline': s.deviceOfflineEnabled,
        'deviceOnline': s.deviceOnlineEnabled,
        'speedAlert': s.speedAlertEnabled,
        'dndEnabled': s.dndEnabled,
        'dndStartMinutes': _toMinutes(s.dndStart),
        'dndEndMinutes': _toMinutes(s.dndEnd),
        'dndDays': s.dndDays.toList()..sort(),
      };

  /// Merge server prefs over [local]. Sound/vibration stay local.
  NotificationSettings _mergeFromServer(
      Map<String, dynamic> p, NotificationSettings local) {
    return NotificationSettings(
      geofenceEnterEnabled: p['geofenceEnter'] as bool? ?? true,
      geofenceExitEnabled: p['geofenceExit'] as bool? ?? true,
      batteryLowEnabled: p['batteryLow'] as bool? ?? true,
      deviceOfflineEnabled: p['deviceOffline'] as bool? ?? true,
      deviceOnlineEnabled: p['deviceOnline'] as bool? ?? false,
      speedAlertEnabled: p['speedAlert'] as bool? ?? false,
      soundEnabled: local.soundEnabled,
      vibrationEnabled: local.vibrationEnabled,
      dndEnabled: p['dndEnabled'] as bool? ?? false,
      dndStart: _fromMinutes(p['dndStartMinutes']),
      dndEnd: _fromMinutes(p['dndEndMinutes']),
      dndDays: (p['dndDays'] as List?)?.whereType<int>().toSet(),
    );
  }

  /// Fetch server prefs; null on any failure (caller keeps local).
  Future<NotificationSettings?> fetch(NotificationSettings local) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/notification-prefs'),
              headers: await _authHeaders())
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final prefs = json['prefs'];
      if (prefs is! Map<String, dynamic>) return null;
      return _mergeFromServer(prefs, local);
    } catch (_) {
      return null;
    }
  }

  /// Push [settings] to the server. Returns true on success.
  Future<bool> push(NotificationSettings settings) async {
    try {
      final res = await _client
          .put(Uri.parse('$baseUrl/notification-prefs'),
              headers: await _authHeaders(),
              body: jsonEncode(_toServerJson(settings)))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close();
}
