// PetTrack Constants
class AppConstants {
  // API URLs
  //
  // All three services served at https://api.mybesti.co behind nginx
  // (real Let's Encrypt cert, auto-renew via certbot.timer):
  //   /api    → provisioning-api  (port 3001)
  //   /push   → push-service      (port 3002)
  //   /traccar→ Traccar           (port 8082) — reverse-proxied with
  //                                WebSocket upgrade support so the
  //                                Flutter live-position stream uses
  //                                wss:// instead of plaintext ws://.
  //
  // Escape hatches below stay commented; uncomment to revert per-service
  // back to the droplet IP if something breaks. The corresponding
  // NSAppTransportSecurity exception in ios/Runner/Info.plist was
  // removed once the Traccar proxy shipped; re-adding it is a one-block
  // edit if you need to fall back temporarily.
  static const String traccarBaseUrl = 'https://api.mybesti.co/traccar';
  static const String provisioningApiUrl = 'https://api.mybesti.co/api';
  static const String pushServiceUrl = 'https://api.mybesti.co/push';
  // Escape hatches (require restoring NSAppTransportSecurity exception):
  // static const String traccarBaseUrl = 'http://64.23.156.25:8082';
  // static const String provisioningApiUrl = 'https://64.23.156.25/api';
  // static const String pushServiceUrl = 'https://64.23.156.25/push';

  // API Endpoints
  static String get traccarApiUrl => '$traccarBaseUrl/api';
  static String get traccarWebSocketUrl =>
      'wss://api.mybesti.co/traccar/api/socket';
  
  // App Info
  static const String appName = 'My Besti';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'soporte@mybesti.co';

  // WhatsApp support: Nico's direct line. Used in two surfaces:
  //   - Paywall ("Tengo dudas de la suscripción de My Besti")
  //   - Cuenta → Soporte ("Necesito ayuda con mi app My Besti")
  // Number in international format without the +, as wa.me requires.
  static const String supportWhatsAppPhone = '573125220165';

  /// Builds a wa.me deep link with the given prefilled message.
  /// Uri.https handles URL encoding of the text param automatically.
  static Uri whatsAppSupportLink(String message) => Uri.https(
        'wa.me',
        '/$supportWhatsAppPhone',
        {'text': message},
      );
  
  // Subscription Pricing (COP)
  //
  // 2026-05-28: dropped 29,900 → 19,900 to match Play Console pricing
  // (Google first; Apple aligned same day). Same price both stores to
  // avoid cross-platform support / refund confusion.
  //
  // This is a FALLBACK shown if StoreKit / Play Billing hasn't resolved
  // the live store price yet — the paywall otherwise prefers
  // `sub.product?.price` (the localized store string, e.g. "COP $19,900").
  static const int monthlyPrice = 19900;
  static const int annualPrice = 250000;
  
  // Limits (MVP)
  static const int maxPetsPerUser = 1;
  static const int maxGeofencesPerPet = 3;
  
  // Tracking
  // Detail-screen refresh cadence. 300s until 2026-08-04: that was set
  // when the Traccar WebSocket was assumed to always be up, so polling
  // was only a distant backstop. In practice the socket drops often on
  // mobile (network handover, background, battery saver) and the map
  // then went up to five minutes stale while the collar reported every
  // 10s. TraccarProvider now runs a 30s degraded poller whenever the
  // socket is down; this value is the screen-level backstop on top of
  // that, so it no longer needs to be a five-minute gamble.
  static const int normalUpdateIntervalSeconds = 60; // 1 minute
  static const int liveUpdateIntervalSeconds = 10; // 10 seconds
  static const int batteryLowThreshold = 20; // 20%
  
  // Map
  static const double defaultZoom = 15.0;
  static const double defaultLatitude = 4.6097; // Bogotá
  static const double defaultLongitude = -74.0817;
}

/// Battery display helper.
///
/// The gateway converts the collar's voltage to a percentage with
/// Mictrack's published curve, whose FLOOR is 5% for anything under
/// 3.40 V — the point where the modem can no longer transmit. So "5%"
/// never means "a little charge left", it means the collar is done.
///
/// Customer report 2026-07-31: "cuando el dispositivo está en 5% ya no
/// funciona". They were right: showing 5% implied there was still some
/// runtime. We now say so plainly.
class BatteryDisplay {
  /// Below (and including) this the collar cannot transmit.
  static const int emptyThreshold = 5;

  static bool isEmpty(int? percent) =>
      percent != null && percent <= emptyThreshold;

  /// Human label: "Batería agotada" at the floor, "NN%" otherwise, "—"
  /// when we have no reading at all.
  ///
  /// 2026-08-13: was "Sin batería", which in Spanish reads ambiguously as
  /// "no battery fitted" rather than "the battery ran out" — the founder
  /// hit exactly that reading during a field test. "Agotada" can only
  /// mean drained.
  static String label(int? percent) {
    if (percent == null) return '—';
    if (isEmpty(percent)) return 'Batería agotada';
    return '$percent%';
  }
}
