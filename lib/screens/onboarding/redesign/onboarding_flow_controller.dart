// OnboardingFlowController — orchestrates the full A4 → A5 → A6 onboarding
// using the redesigned screens. Owns the linear sequence, the cross-screen
// payload (IMEI / first-fix position / chosen home / radius), and the
// navigation glue that hands each screen its `onContinue` callback.
//
// Sequence:
//   A4.1 Intro
//     → A4.2 QR scan  ── (or fallback) → A4.3 Manual IMEI
//                                          ↘
//   A4.4 Paired
//     → A5.1 Searching ── (slow path) → A5.3 Taking longer
//                                          ↘
//   A5.2 First fix
//     → A6.1 Pick location
//        → A6.2 Set radius
//           → A6.3 Configuring (existing setup_geofence_screen overlay
//              wraps the SCAN/AP/GEO/MODE,8 wizard you already shipped)
//              → A6.5 Done   on success
//              → A6.4 Queued on QUEUED_EXPIRED
//
// Today this controller is wired up but NOT YET INVOKED — the legacy
// onboarding (qr_scanner_screen → pet_profile_screen → first_position_
// screen → setup_geofence_screen) still runs by default. To cut over, a
// follow-up commit changes home_screen.dart's `_startOnboarding` (or
// wherever the entry point lives) to push `OnboardingFlowController`
// instead. Keeping the cut-over as a separate change makes rollback
// trivial.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../home/home_screen.dart';
import 'a4_intro_screen.dart';
import 'a4_manual_imei_screen.dart';
import 'a4_paired_screen.dart';
import 'a4_qr_scan_screen.dart';
import 'a5_first_fix_screen.dart';
import 'a5_searching_screen.dart';
import 'a5_taking_longer_screen.dart';
import 'a6_done_screen.dart';
import 'a6_pick_location_screen.dart';
import 'a6_queued_screen.dart';
import 'a6_set_radius_screen.dart';

/// Cross-screen state collected as the user advances through onboarding.
class OnboardingPayload {
  String? imei;
  LatLng? firstFix;
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
      onContinue: () => _replace(_searching()),
    );
  }

  // ─── A5 GPS fix ────────────────────────────────────────────────────

  Widget _searching() {
    // In the cut-over commit this screen subscribes to the gateway's
    // online-state stream so the 3 status rows animate as cell-attaches
    // → GPS-locks → first frame arrives. For now we render a static
    // "all 3 active" view; the screen accepts the live `steps` list so
    // the integration is just a Provider/Stream wire-up.
    return A5SearchingScreen.canonical(
      cellular: SearchStepStatus.done,
      gps: SearchStepStatus.active,
      firstFix: SearchStepStatus.pending,
    );
  }

  // First-fix and taking-longer are reachable from _searching once it
  // becomes stream-driven. Helpers below are exposed so the wire-up
  // commit can route to them without re-deriving the navigation logic.

  Widget firstFixScreenFor(LatLng position, {String? address}) {
    _payload.firstFix = position;
    return A5FirstFixScreen(
      position: position,
      addressLabel: address,
      accuracyMeters: 4.8,
      satellites: 11,
      batteryPercent: 94,
      onDefineSafeZone: () => _replace(_pickLocation(position)),
    );
  }

  Widget takingLongerScreen() {
    return A5TakingLongerScreen(
      onKeepWaiting: () => Navigator.of(context).pop(),
      onTryLater: _exitToHome,
    );
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
