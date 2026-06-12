import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/events/identify.dart';
import 'package:flutter/foundation.dart';

/// Thin singleton wrapper around the Amplitude Flutter SDK (v4.x).
///
/// Usage:
///   AmplitudeService.instance.track('Event Name', properties: {...});
///   AmplitudeService.instance.setUserId(uid);
///   AmplitudeService.instance.setUserProperty('plan', 'active');
///   AmplitudeService.instance.reset();
///
/// Call [init] once from main.dart before runApp.
///
/// The API key is injected at build time via --dart-define so it is never
/// committed to source control:
///   flutter run       --dart-define=AMPLITUDE_API_KEY=KEY
///   flutter build ipa --dart-define=AMPLITUDE_API_KEY=KEY
///
/// If the key is omitted the service disables itself gracefully — the app
/// runs normally, it just emits no Amplitude events.
///
/// NOTE: written against amplitude_flutter ^4.x. The 4.x SDK replaced the
/// legacy `Amplitude.getInstance()` / `logEvent()` API with an instance
/// built from a `Configuration` plus `track(BaseEvent(...))`. Do not
/// reintroduce the old calls — they do not exist in 4.x and will not
/// compile.
class AmplitudeService {
  AmplitudeService._();
  static final AmplitudeService instance = AmplitudeService._();

  Amplitude? _client;
  bool _initialized = false;

  static const String _apiKey = String.fromEnvironment('AMPLITUDE_API_KEY');

  Future<void> init() async {
    if (_initialized) return;
    if (_apiKey.isEmpty) {
      debugPrint(
        'AmplitudeService: AMPLITUDE_API_KEY not set - tracking disabled. '
        'Pass --dart-define=AMPLITUDE_API_KEY=KEY at build time.',
      );
      return;
    }
    // optOut in debug builds keeps the Amplitude project clean of dev-time
    // noise (hot-reload restarts the app constantly). Release builds report.
    _client = Amplitude(
      Configuration(apiKey: _apiKey, optOut: kDebugMode),
    );
    await _client!.isBuilt;
    _initialized = true;
  }

  void track(String eventName, {Map<String, dynamic>? properties}) {
    final client = _client;
    if (!_initialized || client == null) return;
    client.track(BaseEvent(eventName, eventProperties: properties));
  }

  void setUserId(String? userId) {
    _client?.setUserId(userId);
  }

  void setUserProperty(String key, dynamic value) {
    _client?.identify(Identify()..set(key, value));
  }

  void setUserProperties(Map<String, dynamic> properties) {
    final client = _client;
    if (client == null) return;
    final identify = Identify();
    for (final entry in properties.entries) {
      identify.set(entry.key, entry.value);
    }
    client.identify(identify);
  }

  /// Clears the userId and device ID — call on sign-out so subsequent
  /// events are not attributed to the previous user. The 4.x SDK's
  /// reset() handles both in one call (the legacy regenerateDeviceId()
  /// no longer exists).
  void reset() {
    _client?.reset();
  }
}
