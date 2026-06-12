// Mode8ConfigurationController — runs the Phase 1 home-setup wizard for a
// given (device, petName, homeCenter, radius). Pure orchestration; emits
// state changes via a Stream<Mode8WizardState>. UI surfaces (legacy
// setup_geofence_screen, new A6ConfiguringScreen) listen + render.
//
// Lifted from setup_geofence_screen.dart::_createGeofence on 2026-05-03 so
// the redesigned A4 → A6 onboarding flow can reuse the wizard logic
// without dragging the legacy screen's pick/radius UI along with it.
//
// Phase 1 contract: post intent → poll status → on `configured`, create
// the server-side Traccar geofence so alerts evaluate correctly. Failure
// at any step ends in [Mode8WizardState.error] with a human-readable
// reason on `lastError`.

import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

import '../models/device.dart';
import '../providers/traccar_provider.dart';
import '../screens/onboarding/mode8_wizard_state.dart';
import '../utils/bssid.dart';
import 'provisioning_api.dart';

/// Outcome of `run()` — exactly one of these is delivered when the
/// wizard ends. UI uses this to decide which terminal screen to show
/// (Done / Queued / Error).
sealed class Mode8WizardOutcome {
  const Mode8WizardOutcome();
}

class Mode8WizardSuccess extends Mode8WizardOutcome {
  final int traccarGeofenceId;
  const Mode8WizardSuccess({required this.traccarGeofenceId});
}

/// The intent expired before the device came online to run SCAN. Caller
/// should show A6 Queued ("we'll keep trying when Petti connects").
class Mode8WizardQueued extends Mode8WizardOutcome {
  final int stepsCompleted;
  const Mode8WizardQueued({required this.stepsCompleted});
}

/// Hard failure. Caller shows error UI with retry.
class Mode8WizardError extends Mode8WizardOutcome {
  final String userMessage;
  final String detail;
  const Mode8WizardError({
    required this.userMessage,
    required this.detail,
  });
}

/// Cancel: caller cancelled before terminal. UI dismisses.
class Mode8WizardCancelled extends Mode8WizardOutcome {
  const Mode8WizardCancelled();
}

class Mode8ConfigurationController {
  final Device device;
  final String petName;
  final LatLng homeCenter;
  final int radiusMeters;

  /// Phone-side home-zone (Phase B, 2026-05-11). When [homeBssid] is set,
  /// the backend skips the on-device WiFi SCAN and programs the MT710's
  /// AP slot with this BSSID directly. [homeSsid] is stored on the
  /// intent for display purposes (settings "Casa configurada: ...").
  ///
  /// Both fields are optional for back-compat with the legacy A-flow
  /// that still uses device-side SCAN. New onboarding + the Settings
  /// "Configurar zona de casa" path always supply them.
  final String? homeBssid;
  final String? homeSsid;

  /// Optional ProvisioningApi injection for tests.
  final ProvisioningApi? api;

  Mode8ConfigurationController({
    required this.device,
    required this.petName,
    required this.homeCenter,
    required this.radiusMeters,
    this.homeBssid,
    this.homeSsid,
    this.api,
  });

  final _stateController = StreamController<Mode8WizardState>.broadcast();
  Stream<Mode8WizardState> get state => _stateController.stream;

  Mode8WizardState _current = Mode8WizardState.idle;
  Mode8WizardState get currentState => _current;

  bool _cancelled = false;
  bool _disposed = false;

  void _emit(Mode8WizardState s) {
    if (_disposed) return;
    _current = s;
    _stateController.add(s);
  }

  /// Drive the wizard end-to-end. Resolves with the terminal outcome.
  /// Caller is responsible for navigating based on the outcome shape.
  ///
  /// Needs a BuildContext only because the Traccar geofence creation
  /// reads from TraccarProvider (Provider.of). Caller should ensure the
  /// context is still mounted when this resolves.
  Future<Mode8WizardOutcome> run(BuildContext context) async {
    final apiClient = api ?? ProvisioningApi();
    final imei = device.uniqueId;

    _emit(Mode8WizardState.scanning);

    final intentId = const Uuid().v4();

    final HomeSetupIntent posted;
    try {
      // 2026-05-21: when we have a phone-side BSSID, expand to the
      // original + ±1 neighbors (covers the dual-band-router case where
      // the phone connected to 5 GHz but the MT710 scans 2.4 GHz with
      // last-byte-1 BSSID, or vice versa). See utils/bssid.dart for
      // the full rationale. Backend stores all three in
      // device_desired_state.target_macs and ships them verbatim to
      // the device firmware (AP,,,MAC1,MAC2,MAC3). Single-BSSID legacy
      // path is preserved for the device-scan branch (homeBssid null).
      posted = await apiClient.postHomeSetup(
        imei: imei,
        intentId: intentId,
        homeLat: homeCenter.latitude,
        homeLng: homeCenter.longitude,
        radiusMeters: radiusMeters,
        petName: petName,
        homeBssids: homeBssid != null ? bssidWithNeighbors(homeBssid!) : null,
        homeSsid: homeSsid,
      );
    } on HomeSetupApiException catch (e) {
      _emit(Mode8WizardState.error);
      return Mode8WizardError(
        userMessage: 'No pudimos enviar la configuración',
        detail: e.toString(),
      );
    }

    // Client-side polling timeout for the in-flight runner. When the
    // device is asleep / out of range, the gateway holds each command
    // in its queue for up to 4h (post-2026-05-11 TTL bump). Each step
    // of the runner blocks on `await sendGatewayCommand`, so the
    // intent can stay in 'reconciling' for hours. The wizard can't sit
    // on a spinner that long — bail out after [pollDeadline] and
    // return Mode8WizardQueued so the UI shows "se aplicará cuando tu
    // mascota despierte". The runner keeps going in the background;
    // a future settings entry refresh will reflect the eventual
    // configured state.
    //
    // 2026-05-11: started at 30s, reduced to 8s after a live run where
    // 30s of spinner felt broken. An online device completes all 4
    // commands (AP/GEO/MODE/LEP) in under 5s; 8s gives some headroom
    // without making the offline case feel like a hang.
    final pollDeadline = DateTime.now().add(const Duration(seconds: 8));

    HomeSetupIntent latest = posted;
    while (!latest.isTerminal) {
      if (_cancelled) return const Mode8WizardCancelled();
      if (DateTime.now().isAfter(pollDeadline)) {
        // Still 'pending' or 'reconciling' after 30s — runner is
        // waiting on the device. Return queued so the user gets a
        // friendly terminal state.
        _emitForStep(latest.step);
        return Mode8WizardQueued(stepsCompleted: _stepsCompletedFor(latest));
      }
      _emitForStep(latest.step);
      await Future.delayed(const Duration(seconds: 2));
      try {
        final next = await apiClient.getHomeSetupIntent(
          imei: imei,
          intentId: intentId,
        );
        if (next == null) {
          _emit(Mode8WizardState.error);
          return const Mode8WizardError(
            userMessage: 'Perdimos el rastro de la configuración',
            detail: 'intent_lookup_404',
          );
        }
        latest = next;
      } on HomeSetupApiException catch (_) {
        // Transient poll failure — server has the intent durable, keep
        // trying. After several consecutive failures we'd surface;
        // Phase 1 keeps it simple.
        continue;
      }
    }

    if (_cancelled) return const Mode8WizardCancelled();

    if (latest.status == 'cancelled') return const Mode8WizardCancelled();

    if (latest.status == 'superseded') {
      _emit(Mode8WizardState.error);
      return Mode8WizardError(
        userMessage: 'Iniciaste otra configuración',
        detail: 'superseded by ${latest.supersededBy}',
      );
    }

    if (latest.status == 'failed') {
      // Distinguish queue-expired from hard failure. The Phase 1 inline
      // runner sets lastError starting with "scan_failed: queued
      // command expired" when the device never came online for SCAN.
      // That case maps to Queued (caller shows "esperando a Petti")
      // rather than a hard error.
      final err = latest.lastError ?? '';
      if (err.contains('queued command expired')) {
        return Mode8WizardQueued(stepsCompleted: _stepsCompletedFor(latest));
      }
      _emit(Mode8WizardState.error);
      return Mode8WizardError(
        userMessage: _spanishForFailedStep(latest),
        detail: err,
      );
    }

    // status is configured (or verified, Phase 3+).
    // Server-side confirmed device-side commit. Now create the Traccar
    // geofence so alert evaluation works.
    _emit(Mode8WizardState.creatingTraccarGeofence);

    if (!context.mounted) {
      // Caller navigated away. Best-effort: still try to create the
      // geofence using a captured TraccarProvider, but if context is
      // gone we skip and surface a soft error.
      return const Mode8WizardError(
        userMessage: 'No pudimos terminar de guardar en el servidor',
        detail: 'context_unmounted_before_traccar_step',
      );
    }

    // Client-side Traccar geofence creation.
    //
    // ⚠️ The backend's homeSetupRunner ALREADY creates and links the
    // Traccar geofence on the user's behalf via its admin session
    // (see logs: "homeSetupRunner: Traccar geofence registered" +
    // "Linked geofence X to user Y"). This client-side call is
    // therefore redundant — but kept for two reasons:
    //
    //   1. It pulls the geofence into the user's TraccarProvider state
    //      immediately, so the Mapa shows it without waiting for the
    //      next refresh tick.
    //   2. The legacy A6 onboarding path (a6_configuring_screen.dart)
    //      consumes the returned geofenceId.
    //
    // Failure here is NON-FATAL: the backend has already done the
    // server-side work; a duplicate-create from the user session can
    // collide with the admin-created one (name conflict, racy session
    // lookup, etc.) and we don't want to roll back a successful setup
    // because of it. Log + continue with id=0 so the success step
    // still fires and the user lands in the app.
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final geofenceId = await traccar.createCircularGeofence(
      name: 'Casa de $petName',
      latitude: homeCenter.latitude,
      longitude: homeCenter.longitude,
      radiusMeters: radiusMeters.toDouble(),
      deviceId: device.requireTraccarId(),
    );

    if (geofenceId == null) {
      if (kDebugMode) {
        debugPrint(
          'Mode8Controller: client-side Traccar geofence create failed '
          'but backend already created one — continuing. detail=${traccar.errorMessage}',
        );
      }
    }

    _emit(Mode8WizardState.success);
    return Mode8WizardSuccess(traccarGeofenceId: geofenceId ?? 0);
  }

  /// User-initiated cancel (e.g., back button). Marks the controller as
  /// cancelled so `run()` returns `Mode8WizardCancelled` at the next
  /// poll boundary. Does NOT cancel commands already in flight on the
  /// device — those are best-effort, fire-and-forget after dispatch.
  void cancel() {
    _cancelled = true;
  }

  void dispose() {
    _disposed = true;
    _stateController.close();
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  void _emitForStep(String? step) {
    switch (step) {
      case 'scan':
        _emit(Mode8WizardState.scanning);
        break;
      case 'ap':
        _emit(Mode8WizardState.settingMacs);
        break;
      case 'geo':
        _emit(Mode8WizardState.settingHomeZone);
        break;
      case 'mode':
        _emit(Mode8WizardState.enteringMode8);
        break;
      // pending / null — leave prior state to avoid flicker.
    }
  }

  int _stepsCompletedFor(HomeSetupIntent intent) {
    // Map current_step at fail-time to a count of steps that succeeded
    // before failure. SCAN failed = 0; AP failed = 1; GEO failed = 2;
    // MODE failed = 3.
    switch (intent.step) {
      case 'scan':  return 0;
      case 'ap':    return 1;
      case 'geo':   return 2;
      case 'mode':  return 3;
      default:      return 0;
    }
  }

  String _spanishForFailedStep(HomeSetupIntent intent) {
    switch (intent.step) {
      case 'scan': return 'No pudimos leer las redes WiFi de tu casa';
      case 'ap':   return 'No pudimos memorizar tu casa';
      case 'geo':  return 'No pudimos dibujar tu zona segura';
      case 'mode': return 'No pudimos activar el ahorro de batería';
      default:     return 'No pudimos terminar la configuración';
    }
  }
}
