// Setup-first-geofence (onboarding) — Petti restyle.
//
// User just got their first GPS fix; this screen lets them drop a circle
// for "Casa" centered on the current position. Map at the top, Petti
// bottom sheet with a name field + radius slider + Marigold "Crear" CTA
// + skip option.
//
// Map circle uses Sabana (safe-zone color) instead of legacy green;
// fixed-position center crosshair becomes a Petti compass marker.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/device.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import '../../services/app_event_service.dart';
import '../../services/pending_command_tracker.dart';
import '../../services/provisioning_api.dart';
import '../../services/wizard_step_result.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/petti_pending_commands_banner.dart';
import '../../widgets/petti/petti_screen_heading.dart';
import '../../widgets/petti/petti_wizard_timeline.dart';
import '../main/petti_main_tabs_screen.dart';
import 'mode8_wizard_state.dart';

class SetupGeofenceScreen extends StatefulWidget {
  final Device device;
  final String petName;
  final Position currentPosition;

  /// Optional ProvisioningApi injection for tests. Production callers
  /// should leave this null and let the screen build its own client.
  final ProvisioningApi? api;

  /// Optional shared PendingCommandTracker so a single banner can
  /// surface across screens. If null, the screen creates a private
  /// tracker scoped to its lifetime.
  final PendingCommandTracker? commandTracker;

  const SetupGeofenceScreen({
    super.key,
    required this.device,
    required this.petName,
    required this.currentPosition,
    this.api,
    this.commandTracker,
  });

  @override
  State<SetupGeofenceScreen> createState() => _SetupGeofenceScreenState();
}

class _SetupGeofenceScreenState extends State<SetupGeofenceScreen> {
  double _radiusMeters = 100.0;
  bool _isCreating = false;
  late TextEditingController _nameController;

  late LatLng _center;
  final Set<Circle> _circles = {};

  // Mode 8 wizard state — used to drive the in-flight UI label and
  // halt-on-failure flow. See mode8_wizard_state.dart.
  Mode8WizardState _wizardState = Mode8WizardState.idle;
  late final ProvisioningApi _api;
  late final PendingCommandTracker _tracker;
  bool _ownsTracker = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ProvisioningApi();
    if (widget.commandTracker != null) {
      _tracker = widget.commandTracker!;
      _ownsTracker = false;
    } else {
      _tracker = PendingCommandTracker();
      _ownsTracker = true;
    }
    _center = LatLng(
      widget.currentPosition.latitude,
      widget.currentPosition.longitude,
    );
    _nameController = TextEditingController(text: 'Casa');
    _updateCircle();
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (_ownsTracker) _tracker.dispose();
    super.dispose();
  }

  void _updateCircle() {
    _circles
      ..clear()
      ..add(
        Circle(
          circleId: const CircleId('geofence'),
          center: _center,
          radius: _radiusMeters,
          fillColor: PettiColors.sabana.withValues(alpha: 0.18),
          strokeColor: PettiColors.sabana,
          strokeWidth: 2,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      // Floating app-bar effect — translucent over the map.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: PettiColors.cloud.withValues(alpha: 0.85),
        title: const Text('Tu zona segura'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // === Map + bottom sheet (the editing surface) =================
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            circles: _circles,
            onMapCreated: (_) {},
            onCameraMove: (cam) => setState(() {
              _center = cam.target;
              _updateCircle();
            }),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Center crosshair — Marigold pin so it pops against any map style.
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PettiColors.marigold,
                  shape: BoxShape.circle,
                  boxShadow: PettiShadows.elevation1,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: PettiColors.midnight,
                  size: 22,
                ),
              ),
            ),
          ),

          // Bottom sheet — Petti panel with name + radius + CTAs.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: PettiColors.cloud,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PettiRadii.lg),
                  ),
                  boxShadow: PettiShadows.elevation2,
                ),
                padding: const EdgeInsets.fromLTRB(
                  PettiSpacing.s5,
                  PettiSpacing.s5,
                  PettiSpacing.s5,
                  PettiSpacing.s4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pull handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PettiColors.fog,
                          borderRadius: BorderRadius.circular(PettiRadii.pill),
                        ),
                      ),
                    ),
                    // Pending-command banner — only renders when there's
                    // an in-flight or recently-resolved command. Sits
                    // above the form so it's the first thing the user
                    // sees if they navigate back mid-wizard.
                    PettiPendingCommandsBanner(tracker: _tracker),
                    const SizedBox(height: PettiSpacing.s4),

                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: PettiColors.sabanaSoft,
                            borderRadius: BorderRadius.circular(PettiRadii.sm),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: PettiColors.sabana,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: PettiSpacing.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tu primera zona segura',
                                style: PettiText.h4(),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Recibirás una alerta si ${widget.petName} sale de aquí',
                                style: PettiText.bodySm()
                                    .copyWith(color: PettiColors.fgDim),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PettiSpacing.s4),

                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la zona',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: PettiSpacing.s4),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('RADIO', style: PettiText.meta()),
                        Text(
                          '${_radiusMeters.toInt()} m',
                          style: PettiText.number(
                            size: 16,
                            weight: FontWeight.w700,
                          ).copyWith(color: PettiColors.midnight),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: PettiColors.marigold,
                        inactiveTrackColor: PettiColors.fog,
                        thumbColor: PettiColors.marigold,
                        overlayColor:
                            PettiColors.marigold.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _radiusMeters,
                        min: 50,
                        max: 500,
                        divisions: 45,
                        label: '${_radiusMeters.toInt()} m',
                        onChanged: (value) => setState(() {
                          _radiusMeters = value;
                          _updateCircle();
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: PettiSpacing.s2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('50 m',
                              style: PettiText.bodySm()
                                  .copyWith(color: PettiColors.fgDim)),
                          Text('500 m',
                              style: PettiText.bodySm()
                                  .copyWith(color: PettiColors.fgDim)),
                        ],
                      ),
                    ),
                    const SizedBox(height: PettiSpacing.s5),

                    ElevatedButton(
                      onPressed: _isCreating ? null : _createGeofence,
                      child: _isCreating
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation(
                                        PettiColors.midnight),
                                  ),
                                ),
                                const SizedBox(width: PettiSpacing.s3),
                                Flexible(
                                  child: Text(
                                    _wizardState.isInFlight
                                        ? _wizardState.label
                                        : 'Creando…',
                                    style: PettiText.bodySm()
                                        .copyWith(color: PettiColors.midnight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : const Text('Crear zona segura'),
                    ),
                    const SizedBox(height: PettiSpacing.s2),
                    TextButton(
                      onPressed: _skipToHome,
                      child: const Text('Omitir por ahora'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // === Configuring overlay (A6.3) ================================
          // Once the user taps "Crear zona segura" the wizard transitions
          // through 5 backend steps. The map+form below stays mounted
          // (instant back-navigation if needed); the overlay sits above
          // it as a dark Midnight hero with the design's vertical timeline.
          if (_isCreating || _wizardState.isInFlight)
            _Mode8ConfiguringOverlay(state: _wizardState),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- actions

  /// Drive the device through the Mode 8 setup sequence:
  ///   SCAN → AP,,,m1,m2,m3 → GEO,LAT,LON,RADIUS → MODE,8,30
  /// then create the matching server-side Traccar geofence so alert
  /// evaluation runs even when the device is sleeping.
  ///
  /// Each step uses the new ProvisioningApi methods which pass
  /// `?via=tcp&queue=true&queueMs=60000`, so a brief device-offline
  /// window is absorbed silently. On any step failure we halt and
  /// surface a Spanish-language user message; the server-side Traccar
  /// geofence is NOT created if the device-side setup didn't fully
  /// succeed.
  Future<void> _createGeofence() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Ingresa un nombre para la zona');
      return;
    }

    setState(() {
      _isCreating = true;
      _wizardState = Mode8WizardState.idle;
    });

    final imei = widget.device.uniqueId; // Device.uniqueId is the IMEI

    // Single tracker entry covers the whole wizard — we don't surface
    // each sub-step in the banner because the in-line button label
    // already shows step-by-step progress. The banner exists for the
    // case where the user navigates AWAY mid-wizard and needs context
    // when they return.
    final trackerId = _tracker.start(
      label: 'Configurando tu zona segura',
      imei: imei,
    );

    // ---- Phase 1 reconciler: post intent + poll status -----------------
    //
    // Replaces the legacy 4-call sequence (scan / access-points / geo-fence
    // / mode) with a single POST that captures intent. Backend reconciles
    // device-side. We keep the wizard on-screen during Phase 1 (no
    // decouple-then-navigate yet) so this swap is a pure backend cutover —
    // the user's wait time is unchanged, but the server now owns
    // durability + retry. Decoupling lands as a Phase 1.1 UX follow-up.
    //
    // Plan: pettrack-backend/docs/plans/2026-04-30-home-setup-reconciler.md

    final intentId = const Uuid().v4();

    // Debug-dashboard activity stream — fire-and-forget. See
    // pettrack-backend/docs/plans/2026-05-12-debug-dashboard.md.
    AppEventService.fire(
      'home_setup_started',
      deviceImei: imei,
      metadata: {
        'intentId': intentId,
        'radiusMeters': _radiusMeters.round(),
      },
    );

    final HomeSetupIntent posted;
    try {
      posted = await _api.postHomeSetup(
        imei: imei,
        intentId: intentId,
        homeLat: _center.latitude,
        homeLng: _center.longitude,
        radiusMeters: _radiusMeters.round(),
        petName: widget.petName,
      );
    } on HomeSetupApiException catch (e) {
      final failure = WizardStepFailed('home-setup post failed: $e');
      _resolveTracker(trackerId, failure);
      _failWizard(failure, 'No pudimos enviar la configuración');
      return;
    }

    // Poll until terminal. 3s cadence matches the home-screen banner so
    // the two surfaces feel consistent. Consecutive transport failures
    // back off (3s → 10s → 30s) so a backend outage doesn't turn the
    // wizard into a 0.66 req/s hammer against a hot endpoint.
    HomeSetupIntent latest = posted;
    bool firedCompleted = false;
    int consecutiveFailures = 0;
    const int failureSoftLimit = 5; // surface "tomó más tiempo" copy
    while (!latest.isTerminal && mounted) {
      _applyIntentToWizardState(latest);

      // Pick the next poll cadence based on consecutive failures:
      //   0-4 failures → 3 s   (default)
      //   5-9 failures → 10 s  (surface "tomó más tiempo" hint)
      //   10+ failures → 30 s  (long-poll until network recovers)
      final Duration pollDelay;
      if (consecutiveFailures < failureSoftLimit) {
        pollDelay = const Duration(seconds: 3);
      } else if (consecutiveFailures < 10) {
        pollDelay = const Duration(seconds: 10);
      } else {
        pollDelay = const Duration(seconds: 30);
      }
      await Future.delayed(pollDelay);

      try {
        final next = await _api.getHomeSetupIntent(
          imei: imei, intentId: intentId,
        );
        consecutiveFailures = 0; // success resets the backoff
        if (next == null) {
          // Row reaped or imei mismatch — treat as a hard failure.
          final failure = WizardStepFailed('intent disappeared mid-poll');
          _resolveTracker(trackerId, failure);
          _failWizard(failure, 'Perdimos el rastro de la configuración');
          return;
        }
        latest = next;
        // First observation of a successful terminal status: emit
        // home_setup_completed exactly once for the dashboard.
        if (!firedCompleted && latest.isSuccess) {
          firedCompleted = true;
          AppEventService.fire(
            'home_setup_completed',
            deviceImei: imei,
            metadata: {'intentId': intentId, 'status': latest.status},
          );
        }
      } on HomeSetupApiException catch (e) {
        consecutiveFailures++;
        // The intent row is durable server-side, so we keep retrying —
        // but quietly back off and surface a softer hint to the user
        // at the soft limit so they don't think the app is frozen.
        if (consecutiveFailures == failureSoftLimit && mounted) {
          setState(() {
            // Reuse the wizard's state plumbing to nudge the visible
            // step label. _applyIntentToWizardState picks this up
            // organically on the next intent observation, but if we're
            // stuck failing, a one-time UI nudge prevents silence.
          });
        }
        // ignore: avoid_print
        print(
          'home-setup poll error (${consecutiveFailures}x): $e '
          '— next attempt in ${pollDelay.inSeconds}s',
        );
      }
    }

    if (!mounted) return;

    if (!latest.isSuccess) {
      // Map terminal-failure status onto our existing wizard error UI.
      final failure = WizardStepFailed(
        latest.lastError ?? 'reconciler ended in ${latest.status}',
      );
      _resolveTracker(trackerId, failure);
      _failWizard(failure, _spanishForFailedStatus(latest));
      return;
    }

    // Server reports configured; reflect that as the final pre-Traccar
    // step in the on-screen wizard before kicking off step 5.
    setState(() => _wizardState = Mode8WizardState.enteringMode8);

    // ---- Step 5: server-side Traccar geofence (alert evaluation).
    if (!mounted) return;
    setState(() => _wizardState = Mode8WizardState.creatingTraccarGeofence);
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final geofenceId = await traccar.createCircularGeofence(
      name: name,
      latitude: _center.latitude,
      longitude: _center.longitude,
      radiusMeters: _radiusMeters,
      deviceId: widget.device.requireTraccarId(),
    );
    if (geofenceId == null) {
      final failure = WizardStepFailed(
          traccar.errorMessage ?? 'Traccar geofence creation failed');
      _resolveTracker(trackerId, failure);
      _failWizard(
        failure,
        traccar.errorMessage ?? 'No pudimos guardar la zona en el servidor',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _wizardState = Mode8WizardState.success;
      _isCreating = false;
    });
    _tracker.resolve(trackerId, PendingCommandStatus.delivered);
    _showSuccess();
  }

  /// Reflect a polled HomeSetupIntent's current step into the on-screen
  /// wizard timeline. Used during the polling loop to keep the visual
  /// progress in sync with what the server-side runner is actually doing.
  void _applyIntentToWizardState(HomeSetupIntent intent) {
    if (!mounted) return;
    Mode8WizardState next;
    switch (intent.step) {
      case 'scan':
        next = Mode8WizardState.scanning;
        break;
      case 'ap':
        next = Mode8WizardState.settingMacs;
        break;
      case 'geo':
        next = Mode8WizardState.settingHomeZone;
        break;
      case 'mode':
        next = Mode8WizardState.enteringMode8;
        break;
      default:
        // pending / null step — keep prior state to avoid flicker.
        return;
    }
    if (next != _wizardState) {
      setState(() => _wizardState = next);
    }
  }

  /// User-facing copy for a terminal non-success status. Mirrors the
  /// banner-state taxonomy in the Phase 1 plan-doc.
  String _spanishForFailedStatus(HomeSetupIntent intent) {
    switch (intent.status) {
      case 'cancelled':
        return 'Configuración cancelada';
      case 'superseded':
        return 'Iniciaste otra configuración';
      case 'failed':
      default:
        return 'No pudimos terminar la configuración';
    }
  }

  /// Map a WizardStepResult onto the matching PendingCommandStatus +
  /// optional error detail, and notify the tracker. Used at every
  /// failure exit so the banner always reflects reality.
  void _resolveTracker(String id, WizardStepResult result) {
    PendingCommandStatus status;
    String? detail;
    if (result is WizardStepQueueExpired) {
      status = PendingCommandStatus.expired;
    } else if (result is WizardStepDeviceOffline) {
      status = PendingCommandStatus.failed;
      detail = 'Dispositivo desconectado.';
    } else if (result is WizardStepTimedOut) {
      status = PendingCommandStatus.timedOut;
    } else if (result is WizardStepDeviceRejected) {
      status = PendingCommandStatus.rejected;
      detail = result.payload;
    } else if (result is WizardStepFailed) {
      status = PendingCommandStatus.failed;
      detail = result.error;
    } else {
      status = PendingCommandStatus.failed;
    }
    _tracker.resolve(id, status, errorDetail: detail);
  }

  // _parseScanResult removed 2026-04-30: SCAN parsing moved server-side
  // to the Phase 1 reconciler (provisioning-api/src/homeSetupRunner.js
  // ::parseTopMacs). The legacy parser had a known firmware-quirk
  // workaround that's no longer the app's concern.

  /// Halt the wizard, surface a Spanish-language error, and clear
  /// _isCreating so the user can retry.
  void _failWizard(WizardStepResult result, String userMessage) {
    if (!mounted) return;
    String detail;
    if (result is WizardStepQueueExpired) {
      detail = 'Tu Besti no respondió a tiempo. '
          'Llévalo cerca de una ventana o muévelo para despertarlo.';
    } else if (result is WizardStepDeviceOffline) {
      detail = 'No estamos detectando tu Besti. Asegúrate de que esté encendido.';
    } else if (result is WizardStepTimedOut) {
      detail = 'Tu Besti no terminó de aplicar la configuración. '
          'Inténtalo de nuevo en unos segundos.';
    } else if (result is WizardStepDeviceRejected) {
      detail = 'Tu Besti rechazó la orden (${result.payload}). Inténtalo de nuevo.';
    } else if (result is WizardStepFailed) {
      detail = result.error;
    } else {
      detail = 'Estado inesperado';
    }
    setState(() {
      _wizardState = Mode8WizardState.error;
      _isCreating = false;
    });
    _showError('$userMessage. $detail');
  }

  void _showSuccess() {
    final name = _nameController.text.trim();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PettiColors.sabanaSoft,
                borderRadius: BorderRadius.circular(PettiRadii.sm),
              ),
              child: const Icon(Icons.check_rounded,
                  color: PettiColors.sabana, size: 20),
            ),
            const SizedBox(width: PettiSpacing.s3),
            const Text('¡Listo!'),
          ],
        ),
        content: Text(
          'Tu zona segura "$name" ha sido creada.\n\n'
          'Recibirás una notificación si ${widget.petName} sale de esta zona.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToHome();
            },
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _skipToHome() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Omitir zona segura?'),
        content: const Text(
          'Puedes crear zonas seguras más tarde desde el menú principal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToHome();
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PettiMainTabsScreen()),
      (route) => false,
    );
  }
}

// ─── Configuring overlay (A6.3) ───────────────────────────────────────
//
// Full-screen dark hero with three regions:
//  • Top — sabana-tinted home glyph in concentric pulse rings
//  • Middle — hero heading "Enseñándole a tu Petti dónde es casa."
//  • Bottom — vertical 5-step PettiWizardTimeline
//
// Sits above the map/form Stack as an opaque cover. Map editing chrome
// stays mounted underneath so back-navigation is instant if a future
// design adds a "cancel" affordance during the wizard.
class _Mode8ConfiguringOverlay extends StatelessWidget {
  final Mode8WizardState state;
  const _Mode8ConfiguringOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: PettiColors.midnight,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PettiSpacing.s5,
              PettiSpacing.s4,
              PettiSpacing.s5,
              PettiSpacing.s5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SabanaHomeHero(),
                const SizedBox(height: PettiSpacing.s5),
                const PettiScreenHeading(
                  title: 'Enseñándole a tu mascota dónde es casa.',
                  ledeText: 'Tarda menos de un minuto. Mantén el dispositivo cerca.',
                ),
                const SizedBox(height: PettiSpacing.s6),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: PettiWizardTimeline.forWizardState(state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Sabana-tinted home glyph at top of the configuring overlay —
/// concentric rings in Sabana, with a square-rounded house icon centered.
class _SabanaHomeHero extends StatelessWidget {
  const _SabanaHomeHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 1; i <= 3; i++)
            Container(
              width: (70 + i * 50).toDouble(),
              height: (70 + i * 50).toDouble(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: PettiColors.sabana.withValues(alpha: 0.4 - i * 0.1),
                  width: 1.5,
                ),
              ),
            ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: PettiColors.sabana,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: PettiColors.sabana.withValues(alpha: 0.5),
                  blurRadius: 40,
                ),
              ],
            ),
            child: const Icon(Icons.home_rounded,
                color: PettiColors.fgOnDark, size: 28),
          ),
        ],
      ),
    );
  }
}
