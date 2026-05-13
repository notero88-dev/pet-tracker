import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

/// Fire-and-forget activity event reporter for the debug dashboard.
///
/// Plan: pettrack-backend/docs/plans/2026-05-12-debug-dashboard.md
///
/// One static call site: `AppEventService.fire('app_opened')` and similar
/// from the relevant lifecycle / UI hooks. The body lands in the
/// `app_events` table on the backend and feeds the Users/DAU panels.
///
/// Deliberately tiny:
///   - No queue, no retry. On a flaky cellular connection a few events
///     get lost. P0 accepts that bias because the dashboard exists to
///     spot patterns, not to bill anyone.
///   - All errors logged via debugPrint and swallowed.
///   - Resolves userId from FirebaseAuth.currentUser?.uid, falling back
///     to 'anon' for pre-login events (cold app_opened).
class AppEventService {
  AppEventService._();

  // Legacy API key — kept as fall-through during Phase B of the auth
  // refactor. Phase C removes it. See provisioning_api.dart for full
  // story.
  static const String _apiKey =
      'pt_prod_427cce864697e6469353e02b9495e32427e266033f93049c54b26ef632a71c92';

  static http.Client _http = http.Client();

  /// Auth headers — mirrors ProvisioningApi._authHeaders. Bearer
  /// when signed in, plus the legacy x-api-key. Server prefers Bearer.
  static Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': _apiKey,
    };
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Token fetch failed — fall through with API key only.
    }
    return headers;
  }

  /// Test seam: tests can substitute a MockClient.
  @visibleForTesting
  static set httpClient(http.Client client) => _http = client;

  /// Fire one event. Returns immediately; the HTTP POST is awaited
  /// internally but the outer caller does not need to await this.
  static Future<void> fire(
    String event, {
    String? deviceImei,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final url = Uri.parse('${AppConstants.provisioningApiUrl}/app-events');
    final body = <String, dynamic>{
      'event': event,
      'userId': uid,
      'clientTimestamp': DateTime.now().toUtc().toIso8601String(),
      if (deviceImei != null) 'deviceImei': deviceImei,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };

    try {
      final res = await _http
          .post(
            url,
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode >= 400) {
        debugPrint(
          'AppEventService: $event -> HTTP ${res.statusCode}: ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('AppEventService: $event failed: $e');
    }
  }
}
