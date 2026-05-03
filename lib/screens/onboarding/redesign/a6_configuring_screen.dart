// A6.3 — "Enseñándole a tu Petti dónde es casa."
//
// Drives the Mode8ConfigurationController and renders the
// Mode8ConfiguringOverlay (lifted from setup_geofence_screen.dart on
// 2026-05-03). On terminal outcome, calls the appropriate callback so
// the OnboardingFlowController can navigate to A6 Done / A6 Queued / a
// retry surface.
//
// Why a dedicated screen instead of overlay-on-A6.2:
//   - The redesigned flow doesn't have a map editor underneath to overlay
//     on (A6 Pick Location and A6 Set Radius are separate screens, not
//     a single map-with-bottom-sheet like the legacy setup_geofence_
//     screen).
//   - Standalone makes the back-navigation story trivial: there's
//     nothing under the overlay; cancel just pops the screen.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/device.dart';
import '../../../services/mode8_configuration_controller.dart';
import '../../../widgets/petti/mode8_configuring_overlay.dart';

class A6ConfiguringScreen extends StatefulWidget {
  final Device device;
  final String petName;
  final LatLng homeCenter;
  final int radiusMeters;

  /// Wizard succeeded. Caller navigates to A6 Done.
  final void Function(int traccarGeofenceId) onSuccess;

  /// Intent expired before device came online. Caller shows A6 Queued.
  final void Function(int stepsCompleted) onQueued;

  /// Hard failure. Caller shows error UI with retry.
  final void Function(String userMessage, String detail) onError;

  /// User cancelled / popped. Caller dismisses.
  final VoidCallback onCancelled;

  const A6ConfiguringScreen({
    super.key,
    required this.device,
    required this.petName,
    required this.homeCenter,
    required this.radiusMeters,
    required this.onSuccess,
    required this.onQueued,
    required this.onError,
    required this.onCancelled,
  });

  @override
  State<A6ConfiguringScreen> createState() => _A6ConfiguringScreenState();
}

class _A6ConfiguringScreenState extends State<A6ConfiguringScreen> {
  late final Mode8ConfigurationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Mode8ConfigurationController(
      device: widget.device,
      petName: widget.petName,
      homeCenter: widget.homeCenter,
      radiusMeters: widget.radiusMeters,
    );
    _start();
  }

  Future<void> _start() async {
    final outcome = await _controller.run(context);
    if (!mounted) return;
    switch (outcome) {
      case Mode8WizardSuccess(:final traccarGeofenceId):
        widget.onSuccess(traccarGeofenceId);
      case Mode8WizardQueued(:final stepsCompleted):
        widget.onQueued(stepsCompleted);
      case Mode8WizardError(:final userMessage, :final detail):
        widget.onError(userMessage, detail);
      case Mode8WizardCancelled():
        widget.onCancelled();
    }
  }

  @override
  void dispose() {
    _controller.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // intercept back button — wizard mid-flight
      child: Scaffold(
        body: StreamBuilder(
          stream: _controller.state,
          initialData: _controller.currentState,
          builder: (context, snapshot) {
            return Mode8ConfiguringOverlay(
              state: snapshot.data ?? _controller.currentState,
              positioned: false,
            );
          },
        ),
      ),
    );
  }
}
