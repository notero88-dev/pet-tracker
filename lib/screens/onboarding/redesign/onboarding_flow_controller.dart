// OnboardingFlowController — orchestrates the full A4 → A6 onboarding
// using the redesigned screens. Owns the linear sequence, the cross-screen
// payload (IMEI / chosen home / radius), and the navigation glue that hands
// each screen its `onContinue` callback.
//
// Sequence (post-2026-04-30):
//   A4.1 Intro
//     → A4.2 QR scan  ── (or fallback) → A4.3 Manual IMEI
//                                          ↘
//   A4.4 Paired
//     → (resolve phone GPS, brief loader)
//        → A6.1 Pick location
//           → A6.2 Set radius
//              → A6.3 Configuring (existing setup_geofence_screen overlay
//                 wraps the SCAN/AP/GEO/MODE,8 wizard you already shipped)
//                 → A6.5 Done   on success
//                 → A6.4 Queued on QUEUED_EXPIRED
//
// Why no A5 anymore:
//   A5 (GPS first-fix wait) used to gate A6 on outdoor-feasibility — when
//   we still hoped to use the device's own GPS as the home center and the
//   SEARCH command as the Mode-8 setup. Both assumptions are gone. The
//   home center is the pin the user drags on A6's map (phone-supplied),
//   and the Mode-8 setup uses the indoor-friendly manual path
//   (SCAN → AP → GEO → MODE,8) where the puck never needs a GPS lock.
//   Forcing users to wait outdoors for a GPS fix that isn't even used was
//   pure friction, so A5 was removed from the flow on 2026-04-30.
//
//   The A5 screen files (a5_searching_screen.dart, a5_first_fix_screen.dart,
//   a5_taking_longer_screen.dart) are intentionally kept on disk —
//   first-fix in particular is reusable as a post-onboarding "watch live
//   position" surface on the home screen. They're just not wired into the
//   onboarding sequence.
//
// Today this controller is wired up but NOT YET INVOKED — the legacy
// onboarding still runs by default. To cut over, a follow-up commit
// changes home_screen.dart's `_startOnboarding` to push
// `OnboardingFlowController` instead. Keeping the cut-over as a separate
// change makes rollback trivial.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;

import '../../home/home_screen.dart';
import '../../../utils/petti_theme.dart';
import 'a4_intro_screen.dart';
import 'a4_manual_imei_screen.dart';
import 'a4_paired_screen.dart';
import 'a4_qr_scan_screen.dart';
import 'a6_done_screen.dart';
import 'a6_pick_location_screen.dart';
import 'a6_queued_screen.dart';
import 'a6_set_radius_screen.dart';

/// Default initial map center when phone GPS is unavailable / denied /
/// timed-out. Bogotá (Plaza de Bolívar) — sensible default for the
/// Colombian launch market. The user drags the pin to wherever home
/// actually is, so this only sets the camera's starting frame.
const LatLng _kDefaultColombiaCenter = LatLng(4.7110, -74.0721);

/// How long we wait for a phone-GPS fix before falling back to the default
/// center. Indoors-on-2G phones can take a while; 6s is the sweet spot
/// between "snappy onboarding" and "we got at least a coarse lock".
const Duration _kPhoneFixTimeout = Duration(seconds: 6);

/// Cross-screen state collected as the user advances through onboarding.
class OnboardingPayload {
  String? imei;
  String? petName;
  LatLng? homeCenter;
  int? homeRadiusMeters;
}

class OnboardingFlowController extends StatefulWidget {
  /// Pet name passed in from earlier auth/profile flow. Used in A6.5
  /// for the hero "${petName} está en casa." copy. Defaults to a
  /// generic placeholder if the upstream flow didn't capture one.
  final String petName;

  const OnboardingFlowController({
    super.key,
    this.petName = 'Tu Petti',
  });

  @override
  State<OnboardingFlowController> createState() =>
      _OnboardingFlowControllerState();
}

class _OnboardingFlowControllerState extends State<OnboardingFlowController> {
  final OnboardingPayload _payload = OnboardingPayload();

  @override
  void initState() {
    super.initState();
    _payload.petName = widget.petName;
  }

  @override
  Widget build(BuildContext context) {
    // Render A4.1 as the entry; every subsequent screen is pushed
    // onto the navigator via _go(). The flow controller itself is
    // intentionally just a dispatch hub.
    return A4IntroScreen(
      onContinue: () => _go(_qrScan()),
      onNotYet: () => Navigator.of(context).pop(),
    );
  }

  // ─── Navigation helpers ────────────────────────────────────────────

  void _go(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _replace(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _exitToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  // ─── A4 device pairing ─────────────────────────────────────────────

  Widget _qrScan() {
    return A4QrScanScreen(
      onCodeFound: (code) {
        // Validate: 15-digit IMEI. Anything else falls back to manual.
        final cleaned = code.replaceAll(RegExp(r'\D'), '');
        if (cleaned.length == 15) {
          _payload.imei = cleaned;
          _replace(_paired());
        } else {
          _replace(_manualImei());
        }
      },
      onManualEntry: () => _replace(_manualImei()),
    );
  }

  Widget _manualImei() {
    return A4ManualImeiScreen(
      onSubmit: (imei) {
        _payload.imei = imei;
        _replace(_paired());
      },
      onBackToScanner: () => _replace(_qrScan()),
    );
  }

  Widget _paired() {
    final imei = _payload.imei ?? '';
    return A4PairedScreen(
      identifier: 'P-$imei',
      onContinue: _continueFromPaired,
    );
  }

  // ─── Bridge from A4 to A6 ──────────────────────────────────────────
  //
  // A6 Pick Location needs an initial map center. With A5 removed we no
  // longer have the device's first GPS fix to draw from, so we use the
  // phone's location instead. This is faster (sub-second indoors with
  // WiFi+cell tower triangulation), works indoors, and arguably gives a
  // better starting frame anyway since "home" is almost always near the
  // owner's phone.
  //
  // Failure modes — all silent fallbacks to _kDefaultColombiaCenter:
  //   - permission denied / denied-forever
  //   - location services disabled at OS level
  //   - timeout (rural 2G phone may take longer than _kPhoneFixTimeout)
  //   - any platform exception
  // The user can drag the pin from the default to wherever home is, so
  // a wrong starting frame is recoverable; refusing to advance because
  // we can't get a fix would be much worse UX.

  Future<void> _continueFromPaired() async {
    // Show a non-blocking loader while we resolve the phone fix. Capped
    // at _kPhoneFixTimeout so even if location services hang the user
    // never sees a stuck spinner.
    final initial = await _resolvePhoneCenter();
    if (!mounted) return;
    _replace(_pickLocation(initial));
  }

  Future<LatLng> _resolvePhoneCenter() async {
    // Show a transient overlay while we ask the OS. Pop it before we
    // navigate away so the back stack stays clean.
    final overlay = _showResolvingOverlay();
    try {
      final fix = await _tryGetPhoneFix().timeout(
        _kPhoneFixTimeout,
        onTimeout: () => null,
      );
      return fix ?? _kDefaultColombiaCenter;
    } catch (_) {
      return _kDefaultColombiaCenter;
    } finally {
      overlay.remove();
    }
  }

  Future<LatLng?> _tryGetPhoneFix() async {
    final l = loc.Location();

    // 1. Make sure location services are on at the OS level.
    bool serviceOn = await l.serviceEnabled();
    if (!serviceOn) {
      serviceOn = await l.requestService();
      if (!serviceOn) return null;
    }

    // 2. App-level permission.
    var perm = await l.hasPermission();
    if (perm == loc.PermissionStatus.denied) {
      perm = await l.requestPermission();
    }
    if (perm != loc.PermissionStatus.granted &&
        perm != loc.PermissionStatus.grantedLimited) {
      return null;
    }

    // 3. Coarse is fine — this is just the camera starting frame.
    await l.changeSettings(accuracy: loc.LocationAccuracy.balanced);
    final data = await l.getLocation();
    if (data.latitude == null || data.longitude == null) return null;
    return LatLng(data.latitude!, data.longitude!);
  }

  /// Inserts a tiny modal-ish overlay onto the root Overlay so the user
  /// gets feedback while phone GPS resolves. Returns the entry so the
  /// caller can remove it. We use the Overlay directly (not a dialog)
  /// because we want navigation away to stay snappy and not contend
  /// with route animations.
  OverlayEntry _showResolvingOverlay() {
    final entry = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: ColoredBox(
          color: PettiColors.midnight.withValues(alpha: 0.55),
          child: const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(PettiColors.cloud),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  // ─── A6 zona segura wizard ─────────────────────────────────────────

  Widget _pickLocation(LatLng initial) {
    return A6PickLocationScreen(
      initialPosition: initial,
      onConfirm: (chosen) {
        _payload.homeCenter = chosen;
        _replace(_setRadius(chosen));
      },
      onBack: () => Navigator.of(context).pop(),
    );
  }

  Widget _setRadius(LatLng center) {
    return A6SetRadiusScreen(
      homeCenter: center,
      onConfirm: (radius) {
        _payload.homeRadiusMeters = radius;
        // The actual SCAN/AP/GEO/MODE,8 wizard runs inside
        // setup_geofence_screen.dart, which already renders the A6.3
        // configuring overlay we shipped earlier. The cut-over commit
        // pushes that screen here and listens for its result.
        // Until then we route directly to A6.5 with the captured state.
        _replace(_done());
      },
      onBack: () => Navigator.of(context).pop(),
    );
  }

  Widget _done() {
    final center = _payload.homeCenter!;
    final radius = _payload.homeRadiusMeters ?? 100;
    return A6DoneScreen(
      petName: _payload.petName ?? 'Tu Petti',
      homeCenter: center,
      radiusMeters: radius,
      onSeeMap: _exitToHome,
      onDefineAnother: () => _replace(_pickLocation(center)),
    );
  }

  /// Public — exposed for the cut-over commit when the wizard's
  /// `WizardStepResult` returns QUEUED_EXPIRED. The number of
  /// completed steps is whatever the wizard reported before the queue
  /// expired.
  Widget queuedScreen({required int stepsCompleted}) {
    return A6QueuedScreen(
      stepsCompleted: stepsCompleted,
      onAcknowledge: _exitToHome,
      onBack: () => Navigator.of(context).pop(),
    );
  }
}
