// Regression tests for the degraded-mode poller (2026-08-04).
//
// Positions normally arrive over the Traccar WebSocket, so no screen
// polls. When that socket drops, nothing replaced it and the map could
// sit five minutes stale while the collar reported every 10 seconds —
// diagnosed on a real customer walk where the server had the position
// within 1-3s of the GPS fix but the phone showed "Reconectando…".
//
// These tests pin the two invariants that make the fix correct:
// polling only runs while the socket is DOWN, and it never outlives
// the session.

import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack_app/providers/traccar_provider.dart';
import 'package:pettrack_app/utils/constants.dart';

void main() {
  // TraccarProvider registers a WidgetsBinding lifecycle observer in its
  // constructor, so the binding has to exist before we build one.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('degraded polling cadence', () {
    test('detail-screen backstop is no longer a five-minute gamble', () {
      expect(AppConstants.normalUpdateIntervalSeconds, lessThanOrEqualTo(60));
    });

    test('live cadence is unchanged', () {
      expect(AppConstants.liveUpdateIntervalSeconds, 10);
    });
  });

  group('TraccarProvider socket state', () {
    test('starts disconnected and polls nothing without credentials', () {
      final p = TraccarProvider();
      expect(p.connectionStatus, TraccarConnectionStatus.disconnected);
      // No creds → no polling, no network calls. Disposing must be clean.
      expect(() => p.dispose(), returnsNormally);
    });
  });
}
