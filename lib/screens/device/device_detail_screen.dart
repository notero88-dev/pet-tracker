// Device detail (live map) — Petti restyle.
//
// The most-used screen daily. Layout:
//   - Full-bleed Google Map (markers + optional history polyline)
//   - Floating header card at top (back, name + status, EN VIVO pill,
//     zonas, refresh, gear icon for Petti DeviceSettings)
//   - Floating bottom info card with address + 3 stat cards + LIVE/
//     historial action row
//   - Floating "comandos" FAB (legacy DeviceCommandsSheet shortcut —
//     left as-is since DeviceSettings already covers most flows)
//   - History viewer slides up from the bottom when "Historial" is
//     tapped; the bottom info card hides while it's showing
//
// Big visual swaps from the legacy version:
//   - Hardcoded green #2D6A4F → PettiColors.midnight / sabana
//   - LIVE pill: red → Marigold (Petti "active state" convention,
//     not danger). The animated white dot stays for "live" feel.
//   - Stat cards: legacy grey-fill / bold-black → Sand surface,
//     PettiText.meta() label, PettiText.number() value
//   - Battery color helper: Sabana / Marigold / Alert thresholds
//     instead of pure RGB values
//   - History trail polyline: Sabana with translucency
//   - Header + bottom panel use elevation-1 Petti shadow

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/geofence.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import '../../services/app_event_service.dart';
import '../../services/device_command_events.dart';
import '../../services/provisioning_api.dart';
import '../../services/reverse_geocoder.dart';
import '../../services/wizard_step_result.dart';
import '../../utils/constants.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/device_commands_sheet.dart';
import '../../widgets/position_history_viewer.dart';
import '../geofence/geofence_list_screen.dart';
import 'device_settings_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  GoogleMapController? _mapController;
  Timer? _updateTimer;
  bool _isLiveMode = false;
  bool _showHistory = false;
  bool _isFlippingMode = false; // true while a Mode 1/8 command is in flight
  late final ProvisioningApi _api = ProvisioningApi();

  // 2026-05-15 — En vivo "Bad file descriptor" fix.
  //
  // When the backend returns 202 'queued' (device offline at tap time —
  // common for Mode-8 idle), we hold the spinner with a different
  // subtitle ("Esperando al collar…") and wait for one of:
  //
  //   a) An FCM `command_completed` data-only push (canonical signal —
  //      fired by gateway → provisioning-api the moment the device
  //      reconnects and ACKs).
  //   b) A 60s safety timeout that falls back to a "se aplicará cuando
  //      Petti vuelva a conectar" message and clears the spinner.
  //
  // We never block the user behind the spinner forever: even on (b) the
  // queued command is still in the gateway and will fire when the device
  // reconnects; the FCM will then arrive separately and surface a banner.
  int? _pendingQueueId;
  Timer? _queuedTimeoutTimer;
  StreamSubscription<CommandCompletedEvent>? _commandEventsSub;
  static const Duration _queuedSpinnerTimeout = Duration(seconds: 60);

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  /// Geofence overlays drawn on the map. Loaded once on screen open from
  /// `TraccarProvider.getGeofencesForDevice(traccarId)`; today there's
  /// typically exactly one (the user's "Casa" zone). Shipped 2026-05-19
  /// so the user can visually see whether Petti is inside her safe area
  /// — the screenshot from 2026-05-19 1:37 PM showed TEST_1 in El Chicó
  /// with no zone overlay, leaving "is she home?" ambiguous.
  final Set<Circle> _circles = {};

  /// Cached safe-zone center + radius for in/out membership checks.
  /// Populated alongside [_circles]. Null until geofences load.
  LatLng? _homeZoneCenter;
  double? _homeZoneRadiusMeters;

  Position? _currentPosition;
  List<Position> _historyPositions = [];
  Position? _selectedHistoryPosition;

  /// Reverse-geocoded neighborhood / place name for the current position
  /// (e.g. "Chico Norte"). Resolved async via ReverseGeocoder; null while
  /// the lookup is in flight or if the geocoder has nothing useful.
  /// Same pattern as the home-screen pet card so both surfaces agree.
  String? _nearestPlace;

  @override
  void initState() {
    super.initState();
    _loadCurrentPosition();
    _startNormalUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _queuedTimeoutTimer?.cancel();
    _commandEventsSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ----------------------------------------------------- data

  void _loadCurrentPosition() {
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final position = traccar.getLastPosition(widget.device.traccarId!);
    if (position != null) {
      setState(() {
        _currentPosition = position;
        _updateMarker(position);
      });
      _resolveNearestPlace(position);
    }
    _loadGeofenceCircles();
  }

  /// Build the GoogleMap [Circle] overlays for every active CIRCLE-type
  /// geofence assigned to this device, and cache the first one (the
  /// "Casa" zone) for in/out membership checks elsewhere in the widget.
  /// Idempotent — safe to call multiple times.
  ///
  /// 2026-05-19 follow-up: TraccarProvider's `_geofences` is normally
  /// empty until the user opens GeofenceListScreen, which is the only
  /// screen that calls `loadGeofences()`. The Mapa screen is loaded on
  /// app open and the user may never visit the geofence list — so we
  /// trigger the fetch ourselves here if the cache is empty, then read
  /// from it. Subsequent visits hit the cache without an API call.
  ///
  /// Color choice: PettiColors.sabana is the design system's "safe-zone /
  /// home / OK" green. 18 % alpha fill keeps map labels readable through
  /// the overlay; 2 px stroke at 70 % alpha makes the boundary obvious
  /// at typical zoom levels (16-17).
  Future<void> _loadGeofenceCircles() async {
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final traccarId = widget.device.traccarId;
    if (traccarId == null) return;

    // Fire a fetch if the cache is empty. await it so subsequent
    // build()s see the new circles. If fetch fails the provider logs
    // the error and we keep an empty list — UI silently falls back to
    // the geocoded place name.
    if (traccar.geofences.isEmpty) {
      await traccar.loadGeofences();
    }
    if (!mounted) return;

    final geofences = traccar.getGeofencesForDevice(traccarId);

    final circles = <Circle>{};
    LatLng? firstCenter;
    double? firstRadius;
    for (final g in geofences) {
      if (g.type != GeofenceType.circle ||
          g.center == null ||
          g.radius == null ||
          !g.isActive) {
        continue;
      }
      circles.add(Circle(
        circleId: CircleId('zone_${g.id}'),
        center: g.center!,
        radius: g.radius!,
        fillColor: PettiColors.sabana.withValues(alpha: 0.18),
        strokeColor: PettiColors.sabana.withValues(alpha: 0.7),
        strokeWidth: 2,
      ));
      firstCenter ??= g.center;
      firstRadius ??= g.radius;
    }

    setState(() {
      _circles
        ..clear()
        ..addAll(circles);
      _homeZoneCenter = firstCenter;
      _homeZoneRadiusMeters = firstRadius;
    });
  }

  /// Haversine distance in meters between [lat1, lng1] and [lat2, lng2].
  /// Used for the in-zone membership check below. Same formula as the
  /// SQL query in `docs/runbooks/postgres-backup.md` so server-side and
  /// client-side answers always agree.
  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusM = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLng = (lng2 - lng1) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusM * 2 * math.asin(math.sqrt(a));
  }

  /// True when the current position is inside the cached home zone.
  /// Returns false when either piece of data isn't loaded yet, so the
  /// UI conservatively shows the geocoded place name in those cases
  /// instead of guessing.
  bool get _isInHomeZone {
    final pos = _currentPosition;
    final center = _homeZoneCenter;
    final radius = _homeZoneRadiusMeters;
    if (pos == null || center == null || radius == null) return false;
    return _haversineMeters(
          pos.latitude, pos.longitude, center.latitude, center.longitude,
        ) <=
        radius;
  }

  /// Kick off a reverse-geocode for [position]. Cache lives in
  /// ReverseGeocoder so consecutive lookups for the same coords (rounded
  /// to ~11 m) hit memory instead of MapKit/Geocoder again. We don't
  /// await — the result lands in [_nearestPlace] via setState whenever
  /// it's ready, and the bottom panel falls back to `position.address`
  /// or coordinates in the meantime.
  Future<void> _resolveNearestPlace(Position position) async {
    final name = await ReverseGeocoder.instance.nearestPlace(
      position.latitude,
      position.longitude,
    );
    if (!mounted) return;
    if (name != _nearestPlace) {
      setState(() => _nearestPlace = name);
    }
  }

  void _startNormalUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(seconds: AppConstants.normalUpdateIntervalSeconds),
      (_) => _refreshPosition(),
    );
  }

  void _startLiveUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(seconds: AppConstants.liveUpdateIntervalSeconds),
      (_) => _refreshPosition(),
    );
  }

  Future<void> _refreshPosition() async {
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    await traccar.refreshDevices();

    final position = traccar.getLastPosition(widget.device.traccarId!);
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
        _updateMarker(position);
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      });
      _resolveNearestPlace(position);
    }
  }

  void _updateMarker(Position position) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: MarkerId('pet-${widget.device.id}'),
        position: LatLng(position.latitude, position.longitude),
        // Marigold-hued marker so the live dot matches the brand.
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: widget.device.name,
          snippet: position.address ?? position.coordinatesText,
        ),
      ),
    );
  }

  /// "Modo LIVE" / "Pet is lost" toggle.
  ///
  /// 2026-05-13: re-implemented on top of LOCK (per the three-state
  /// architecture). The device gets `LOCK,10,5` — 10s reports for 5 min,
  /// then auto-reverts to its previous persistent mode (Mode 8 HOME or
  /// Mode 7 AWAY, depending on which side of the geofence it's on). This
  /// replaces the older MODE,1,30 path that left the device in real-time
  /// mode permanently until manually flipped back, which was a battery
  /// timebomb if the user forgot to disable it.
  ///
  /// On enable: fire LOCK,10,5 → on success, the app's UI flag flips on
  /// for the 5-minute window. We DO NOT need to track the expiry on the
  /// server — the device handles its own revert.
  ///
  /// On disable (user taps "Volver a normal" before the 5min expires):
  /// the app simply flips the UI flag back to false. The device cannot
  /// be told to abort a LOCK early per vendor docs; the 5-minute window
  /// will play out, but the user has already moved on. Acceptable
  /// trade-off for the simpler architecture.
  ///
  /// We surface failures inline (snackbar) without flipping the toggle,
  /// so the visual state always reflects the device's actual mode (or our
  /// best belief of it). Only flip the bool AFTER the device confirms the
  /// command landed.
  ///
  /// Known limitations (this commit):
  ///   - State is per-screen-session. Closing and reopening the screen
  ///     resets to false. Cross-session persistence (shared_preferences
  ///     keyed by IMEI) is a follow-up.
  ///   - The 5-min countdown UI is not yet wired — flag follows the
  ///     button rather than the actual LOCK expiry timer.
  Future<void> _toggleLiveMode() async {
    if (_isFlippingMode) return; // debounce double-tap
    final enabling = !_isLiveMode;

    final confirmed = await _confirmModeFlip(enabling);
    if (!confirmed || !mounted) return;

    setState(() => _isFlippingMode = true);
    // ignore: avoid_print
    print('[ModeFlip] start enabling=$enabling imei=${widget.device.uniqueId}');

    // Debug-dashboard activity stream — fire-and-forget. See
    // pettrack-backend/docs/plans/2026-05-12-debug-dashboard.md.
    AppEventService.fire(
      'live_mode_toggled',
      deviceImei: widget.device.uniqueId,
      metadata: {
        'on': enabling,
        // LOCK params on enable; on disable there's no device-side action.
        if (enabling) 'lockIntervalSeconds': 10,
        if (enabling) 'lockRevertMinutes': 5,
      },
    );

    try {
      final WizardStepResult result;
      try {
        if (enabling) {
          // LIVE: fire LOCK,10,5. Device streams 10s reports for 5 min
          // then auto-reverts to its previous persistent mode.
          result = await _api.lockMode(
            imei: widget.device.uniqueId,
            intervalSeconds: 10,
            revertMinutes: 5,
          );
        } else {
          // Disable: no device-side action — LOCK auto-reverts on its
          // own. Synthesize a success result so the rest of the flow
          // treats this as a normal toggle. The persistent mode is
          // already what push-service set on the last geofence event.
          result = WizardStepOk('UI_FLIP');
        }
      } catch (e, st) {
        // ignore: avoid_print
        print('[ModeFlip] threw: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error de red: $e'),
            backgroundColor: PettiColors.alert,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ));
        }
        return;
      }
      // ignore: avoid_print
      print('[ModeFlip] result=${result.runtimeType} $result');
      if (!mounted) return;

      // 2026-05-15 — "Esperando al collar…" path. Originally written for
      // the WizardStepQueued case only (device offline at tap time, the
      // gateway parks the LOCK for up to 4 h and returns 202). 2026-05-15
      // PM dogfood pass revealed that WizardStepTimedOut and
      // WizardStepQueueExpired ALSO need the same treatment: in Mode 8
      // a device can receive the command, briefly write it, and go back
      // to sleep before sending the REPLY frame within the 30s gateway
      // timeout window. From the user's perspective that's not an error
      // — the command will fire next time the dog moves. Surfacing it as
      // a red error popup is hostile UX and inconsistent with the queued
      // case (which is structurally the same thing under the hood).
      //
      // So: treat any "we don't have a synchronous OK" outcome the same
      // way — hold the spinner, subscribe to FCM completion events, fall
      // back after 60s with a "se activará cuando se mueva" message that
      // doesn't blame the user.
      if (enabling &&
          (result is WizardStepQueued ||
           result is WizardStepTimedOut ||
           result is WizardStepQueueExpired)) {
        _pendingQueueId =
            result is WizardStepQueued ? result.queueId : null;
        _subscribeToCommandEvents();
        _queuedTimeoutTimer?.cancel();
        _queuedTimeoutTimer = Timer(_queuedSpinnerTimeout, () {
          if (!mounted) return;
          _showQueuedFallbackMessage();
          _clearQueuedWait(); // stops the spinner, leaves the command in flight
        });
        // Don't show success yet — keep _isFlippingMode true to hold the
        // spinner. _clearQueuedWait() or the FCM event resets it.
        return;
      }

      if (result is! WizardStepOk) {
        _showModeFlipError(result, enabling);
        return;
      }

      // Device confirmed. Flip UI state + adjust polling cadence to match.
      setState(() => _isLiveMode = enabling);
      if (enabling) {
        _startLiveUpdates();
        final traccar = Provider.of<TraccarProvider>(context, listen: false);
        traccar.requestPositionNow(widget.device.traccarId!);
      } else {
        _startNormalUpdates();
      }
      _showModeFlipSuccess(enabling);
    } finally {
      // For the queued branch we hold _isFlippingMode=true until the
      // event lands or the safety timer fires. Only the synchronous
      // success/error paths clear it here.
      if (mounted && _pendingQueueId == null) {
        setState(() => _isFlippingMode = false);
      }
    }
  }

  /// Start listening for command-completion FCM events. Idempotent.
  /// Caller must have set [_pendingQueueId] first.
  void _subscribeToCommandEvents() {
    _commandEventsSub?.cancel();
    _commandEventsSub =
        DeviceCommandEvents.instance.stream.listen(_onCommandEvent);
  }

  /// React to a `command_completed` FCM. Filters on our IMEI + (if
  /// available) queueId. Anything else is for a different screen/flow.
  void _onCommandEvent(CommandCompletedEvent event) {
    if (!mounted) return;
    if (event.imei != widget.device.uniqueId) return;
    if (event.command != 'lock') return;
    // If we have a specific queueId, prefer that as the discriminant.
    // If the FCM didn't carry one (legacy), fall back to imei+command.
    if (_pendingQueueId != null &&
        event.queueId != null &&
        event.queueId != _pendingQueueId) {
      return;
    }
    if (event.isSuccess) {
      _onQueuedCommandSucceeded();
    } else {
      _onQueuedCommandFailed(event);
    }
  }

  /// FCM said the queued LOCK acked. Flip UI to "En vivo" same as the
  /// synchronous-success path would have.
  void _onQueuedCommandSucceeded() {
    _clearQueuedWait();
    setState(() {
      _isLiveMode = true;
      _isFlippingMode = false;
    });
    _startLiveUpdates();
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    if (widget.device.traccarId != null) {
      traccar.requestPositionNow(widget.device.traccarId!);
    }
    _showModeFlipSuccess(true);
  }

  /// FCM said the queued LOCK reached a terminal non-acked state.
  ///
  /// Three distinct outcomes:
  ///   - 'expired' / 'timeout' / 'evicted' — device was asleep or briefly
  ///      online but didn't ACK in time. Functionally the same: the user
  ///      should just wait for the dog to move and the next attempt will
  ///      land. NOT an error; show as info-style snackbar with friendly
  ///      copy that doesn't blame the user. The previous "no respondió a
  ///      tiempo. Inténtalo de nuevo" was hostile UX for a Mode-8 device
  ///      working exactly as designed.
  ///   - 'failed' — firmware explicitly rejected the command (MODE,FS).
  ///      Rare, indicates a real problem worth surfacing as an alert.
  ///   - 'write_failed' — gateway couldn't write to the socket. Also a
  ///      real error worth flagging.
  ///
  /// (2026-05-15 PM dogfood revealed the original copy was the
  /// single most jarring user-facing failure mode of the new En vivo
  /// flow — the device-not-online case happens often in Mode 8 by design.)
  void _onQueuedCommandFailed(CommandCompletedEvent event) {
    _clearQueuedWait();
    if (!mounted) return;
    setState(() => _isFlippingMode = false);
    final petName = event.petName.isNotEmpty ? event.petName : 'tu mascota';

    final isTransient = event.status == 'expired' ||
        event.status == 'timeout' ||
        event.status == 'evicted';

    final message = switch (event.status) {
      'failed' => '$petName rechazó el cambio de modo. Escríbenos si esto se repite.',
      'write_failed' => 'No pudimos enviar el comando al collar. Inténtalo de nuevo.',
      // expired / timeout / evicted / anything else: same friendly copy.
      _ => 'En vivo se activará cuando $petName se mueva. Te avisaremos en cuanto pase.',
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      // Transient outcomes use the brand-warm midnight background (info-
      // style); only genuine firmware/write failures use alert-red.
      backgroundColor:
          isTransient ? PettiColors.midnight : PettiColors.alert,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
    ));
  }

  void _clearQueuedWait() {
    _queuedTimeoutTimer?.cancel();
    _queuedTimeoutTimer = null;
    _commandEventsSub?.cancel();
    _commandEventsSub = null;
    _pendingQueueId = null;
  }

  /// 60s safety message: command is still queued backend-side but we
  /// release the spinner so the UI isn't held hostage. The FCM (if
  /// permissions granted) will still fire later when the device
  /// connects + acks, surfacing a banner that flips state then.
  ///
  /// Copy matches `_onQueuedCommandFailed`'s transient-outcome message
  /// so the user gets a consistent mental model — whether the FCM
  /// arrives or the safety timeout fires first, the same friendly
  /// "se activará cuando se mueva" is shown.
  void _showQueuedFallbackMessage() {
    if (!mounted) return;
    setState(() => _isFlippingMode = false);
    final petName = widget.device.name.isNotEmpty ? widget.device.name : 'tu mascota';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'En vivo se activará cuando $petName se mueva. Te avisaremos en cuanto pase.',
      ),
      backgroundColor: PettiColors.midnight,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
    ));
  }

  Future<bool> _confirmModeFlip(bool enabling) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(enabling ? '¿Activar modo de búsqueda?' : '¿Volver a modo normal?'),
        content: Text(
          enabling
              ? '${widget.device.name} reportará su ubicación en tiempo real. La batería '
                  'se consumirá mucho más rápido — apaga este modo cuando '
                  'la encuentres.'
              : '${widget.device.name} volverá a modo casa (ahorro de batería). Solo '
                  'reportará cuando salga de la zona segura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: enabling ? PettiColors.alert : PettiColors.sabana,
              foregroundColor: PettiColors.cloud,
            ),
            child: Text(enabling ? 'Buscar a ${widget.device.name}' : 'Volver a normal'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showModeFlipError(WizardStepResult result, bool wasEnabling) {
    String message;
    final petName =
        widget.device.name.isNotEmpty ? widget.device.name : 'tu mascota';
    if (result is WizardStepDeviceOffline) {
      message = 'No estamos detectando a $petName. Verifica que esté encendida.';
    } else if (result is WizardStepTimedOut) {
      message = '$petName no respondió a tiempo. Inténtalo de nuevo en un momento.';
    } else if (result is WizardStepQueueExpired) {
      message = '$petName no se conectó a tiempo. Vuelve a intentar cuando esté en línea.';
    } else if (result is WizardStepDeviceRejected) {
      message = '$petName rechazó el cambio de modo. Inténtalo de nuevo.';
    } else if (result is WizardStepFailed) {
      message = 'No pudimos cambiar el modo: ${result.error}';
    } else {
      message = 'No pudimos cambiar el modo. Inténtalo de nuevo.';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: PettiColors.alert,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 8),
    ));
  }

  void _showModeFlipSuccess(bool enabling) {
    final name = widget.device.name;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      // We optimistically flipped _isLiveMode on a 200 from the API, but the
      // 200 just means the command was dispatched (TCP queue or SMS) — the
      // device itself only acks on its next wake cycle (motion or scheduled
      // poll). Reflect that honestly so the user doesn't think Mode 1 is
      // already live and decide the device is broken when they don't see
      // a fresh position right away.
      content: Text(
        enabling
            ? 'Solicitud enviada. $name entrará en modo búsqueda cuando se mueva.'
            : '$name volverá a modo casa cuando se mueva.',
      ),
      backgroundColor: enabling ? PettiColors.alert : PettiColors.sabana,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }

  // ----------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            DeviceCommandsSheet.show(context, widget.device),
        backgroundColor: PettiColors.midnight,
        foregroundColor: PettiColors.cloud,
        tooltip: 'Comandos',
        child: const Icon(Icons.settings_remote_outlined),
      ),
      body: Stack(
        children: [
          // Map
          _currentPosition != null
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: AppConstants.defaultZoom,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  circles: _circles,
                  onMapCreated: (controller) =>
                      _mapController = controller,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: PettiSpacing.s4),
                      Text(
                        'Cargando ubicación…',
                        style: PettiText.body()
                            .copyWith(color: PettiColors.fgDim),
                      ),
                    ],
                  ),
                ),

          // Top header card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildHeader()),
          ),

          // History viewer (when active)
          if (_showHistory)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: PositionHistoryViewer(
                  positions: _historyPositions,
                  selectedPosition: _selectedHistoryPosition,
                  onPositionSelected: _onHistoryPositionSelected,
                  onClose: _closeHistory,
                ),
              ),
            ),

          // Bottom info panel (when not showing history)
          if (_currentPosition != null && !_showHistory)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: _buildBottomPanel()),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------- header card

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: PettiColors.cloud,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        boxShadow: PettiShadows.elevation1,
        border: Border.all(color: PettiColors.borderLight),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.device.name,
                  style: PettiText.h4(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.device.statusText,
                  style: PettiText.bodySm().copyWith(
                    color: widget.device.isOnline
                        ? PettiColors.sabana
                        : PettiColors.fgDim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_isLiveMode)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PettiSpacing.s3,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: PettiColors.marigold,
                borderRadius: BorderRadius.circular(PettiRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PettiColors.midnight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'EN VIVO',
                    style: PettiText.meta().copyWith(
                      color: PettiColors.midnight,
                      letterSpacing: 0.04 * 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: PettiSpacing.s2),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Zonas seguras',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    GeofenceListScreen(device: widget.device),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshPosition,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes del dispositivo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceSettingsScreen(
                  device: widget.device,
                  petName: widget.device.name,
                  isOnline: _currentPosition != null,
                  lastSeen: _currentPosition?.deviceTime,
                  // 2026-05-12: was `_currentPosition?.attributes?['batteryLevel']
                  // as int? ?? 80`. Traccar serializes batteryLevel as a
                  // double (e.g. 80.0), so `as int?` threw _TypeError every
                  // time the gear icon was tapped — user observed this as a
                  // gray screen because the new route built, errored, and
                  // popped to a blank surface. Position.batteryLevel is the
                  // safe getter — it does `(num).toInt()` and handles nulls.
                  batteryPercent: _currentPosition?.batteryLevel ?? 80,
                ),
              ),
            ),
          ),
          const SizedBox(width: PettiSpacing.s1),
        ],
      ),
    );
  }

  // ----------------------------------------------------- bottom panel

  Widget _buildBottomPanel() {
    final pos = _currentPosition!;
    return Container(
      margin: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: PettiColors.cloud,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        boxShadow: PettiShadows.elevation1,
        border: Border.all(color: PettiColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(PettiSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2026-05-19: header row. When the collar is inside the
                // user's home zone, show "En casa" as the primary state
                // signal (the place name is then irrelevant — the user
                // knows where their own home is). Falls back to the
                // reverse-geocoded neighborhood name when outside the
                // zone, or to Traccar's geocoded address / raw coords
                // before the geocoder has resolved. Same source as the
                // home-screen pet card so both surfaces stay in sync.
                Row(
                  children: [
                    Icon(
                      _isInHomeZone
                          ? Icons.home_rounded
                          : Icons.location_on_outlined,
                      color: PettiColors.sabana,
                      size: 20,
                    ),
                    const SizedBox(width: PettiSpacing.s2),
                    Expanded(
                      child: Text(
                        _isInHomeZone
                            ? 'En casa'
                            : (_nearestPlace ??
                                pos.address ??
                                pos.coordinatesText),
                        style: PettiText.bodyStrong()
                            .copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PettiSpacing.s3),
                // 2026-05-19: Velocidad card removed per founder UX
                // feedback — speed isn't meaningful here (the device is
                // either still at home, walking, or in En vivo mode
                // where the live marker speaks for itself). Now a
                // two-card row: Actualizado + Batería. If a future
                // version brings back the speed signal, prefer a tiny
                // chip inside the En vivo button rather than a 3rd stat.
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.access_time_rounded,
                        label: 'Actualizado',
                        value: _formatTimestamp(pos.deviceTime),
                      ),
                    ),
                    if (pos.batteryLevel != null) ...[
                      const SizedBox(width: PettiSpacing.s2),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.battery_charging_full_rounded,
                          label: 'Batería',
                          value: '${pos.batteryLevel}%',
                          valueColor:
                              _batteryColor(pos.batteryLevel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Action row — Sand surface. Design (chat3.md 2026-05-13):
          // "En vivo" / Buscar is the prominent action — wider (flex 1.4
          // matches the design's ratio), marigold filled, with a pulsing
          // red live-dot and the brand's warm shadow. Historial sits
          // secondary in cream. "Compartir" was removed entirely in the
          // design pass (was never in this codebase either — no-op).
          Container(
            padding: const EdgeInsets.all(PettiSpacing.s3),
            decoration: const BoxDecoration(
              color: PettiColors.sand,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(PettiRadii.md),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 14, // 1.4× wider than Historial — design ratio
                  child: _BuscarPrimaryButton(
                    isLive: _isLiveMode,
                    isLoading: _isFlippingMode,
                    isAwaitingDevice: _pendingQueueId != null,
                    petName: widget.device.name,
                    onTap: _isFlippingMode ? null : _toggleLiveMode,
                  ),
                ),
                const SizedBox(width: PettiSpacing.s2),
                Expanded(
                  flex: 10,
                  child: _HistorialSecondaryButton(
                    showHistory: _showHistory,
                    onTap: _showHistory ? _closeHistory : _loadHistory,
                  ),
                ),
              ],
            ),
          ),
          // Pending-activation caption. The Mode-1 (real-time) command goes
          // out via SMS / TCP queue the moment the user confirms, but the
          // MT710 only processes it on its next wake (motion-triggered or
          // scheduled poll). Until then, the button reads "Detener búsqueda"
          // but no real-time positions are arriving — this caption owns the
          // gap between "request sent" and "device actually in Mode 1".
          if (_isLiveMode)
            Padding(
              padding: const EdgeInsets.only(
                top: PettiSpacing.s2,
                left: PettiSpacing.s3,
                right: PettiSpacing.s3,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: PettiColors.fgDim,
                  ),
                  const SizedBox(width: PettiSpacing.s1),
                  Expanded(
                    child: Text(
                      'El modo de búsqueda se activará cuando '
                      '${widget.device.name} se mueva.',
                      style: PettiText.bodySm().copyWith(
                        color: PettiColors.fgDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(PettiSpacing.s3),
      decoration: BoxDecoration(
        color: PettiColors.sand,
        borderRadius: BorderRadius.circular(PettiRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: PettiColors.fgDim),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: PettiText.meta().copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: PettiText.number(size: 14, weight: FontWeight.w700)
                .copyWith(
              color: valueColor ?? PettiColors.midnight,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Color _batteryColor(int level) {
    if (level >= 60) return PettiColors.sabana;
    if (level >= AppConstants.batteryLowThreshold) {
      return PettiColors.marigoldDim;
    }
    return PettiColors.alert;
  }

  // ----------------------------------------------------- history

  Future<void> _loadHistory() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final history = await traccar.loadPositionHistory(
      deviceId: widget.device.traccarId!,
      from: yesterday,
      to: now,
    );

    if (!mounted) return;
    setState(() {
      _historyPositions = history;
      _showHistory = true;
      _drawHistoryTrail();
    });
  }

  void _drawHistoryTrail() {
    if (_historyPositions.isEmpty) return;

    final points = _historyPositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    _polylines
      ..clear()
      ..add(
        Polyline(
          polylineId: const PolylineId('history_trail'),
          points: points,
          color: PettiColors.sabana.withValues(alpha: 0.7),
          width: 4,
          geodesic: true,
        ),
      );

    if (_historyPositions.length > 1) {
      final start = _historyPositions.last;
      final end = _historyPositions.first;

      _markers.add(
        Marker(
          markerId: const MarkerId('history_start'),
          position: LatLng(start.latitude, start.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Inicio'),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('history_end'),
          position: LatLng(end.latitude, end.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Actual'),
        ),
      );
    }

    if (_mapController != null && _historyPositions.length > 1) {
      final bounds = _calculateBounds(_historyPositions);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  LatLngBounds _calculateBounds(List<Position> positions) {
    double? minLat, maxLat, minLng, maxLng;
    for (final pos in positions) {
      if (minLat == null || pos.latitude < minLat) minLat = pos.latitude;
      if (maxLat == null || pos.latitude > maxLat) maxLat = pos.latitude;
      if (minLng == null || pos.longitude < minLng) minLng = pos.longitude;
      if (maxLng == null || pos.longitude > maxLng) maxLng = pos.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  void _onHistoryPositionSelected(Position position) {
    setState(() {
      _selectedHistoryPosition = position;
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
      _markers
          .removeWhere((m) => m.markerId.value == 'selected_history');
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_history'),
          position: LatLng(position.latitude, position.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(
            title: 'Posición seleccionada',
            snippet: position.address ?? position.coordinatesText,
          ),
        ),
      );
    });
  }

  void _closeHistory() {
    setState(() {
      _showHistory = false;
      _historyPositions = [];
      _selectedHistoryPosition = null;
      _polylines.clear();
      if (_currentPosition != null) {
        _updateMarker(_currentPosition!);
      }
    });
  }
}

// -----------------------------------------------------------------------------
// _BuscarPrimaryButton — the prominent marigold-filled action in the map
// sheet. Per chat3.md design pass (2026-05-13): label is ALWAYS "En vivo"
// (not "Buscar a [pet]") and the pulsing red dot is always shown. The
// design treats this as a constant "live tracking is available — tap to
// activate" affordance, not a stateful toggle. Tapping it fires LOCK,10,5
// which streams 10s positions for 5 min; the device auto-reverts, so
// there's no "off" state to render.
//
// Loading state: subtitle changes briefly to "Cambiando…" while LOCK
// dispatches. After OK reply we go back to "En vivo".
//
// Class kept named _BuscarPrimaryButton for internal lineage even though
// the visible label is "En vivo" — easier to grep for if something
// regresses.
// -----------------------------------------------------------------------------
class _BuscarPrimaryButton extends StatelessWidget {
  final bool isLive;
  final bool isLoading;
  final String petName; // kept for analytics/event firing; not rendered
  final VoidCallback? onTap;
  /// When true the device was offline at tap time and the LOCK is parked
  /// on the gateway waiting for reconnect. The button shows
  /// "Esperando al collar…" instead of "Cambiando…" so the user knows
  /// we're not stuck on the network, we're stuck on the device.
  /// Shipped 2026-05-15 alongside the 202-queued / FCM-completion fix.
  final bool isAwaitingDevice;

  const _BuscarPrimaryButton({
    required this.isLive,
    required this.isLoading,
    required this.petName,
    required this.onTap,
    this.isAwaitingDevice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PettiColors.marigold,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              // Brand-warm shadow per the design spec.
              BoxShadow(
                color: PettiColors.marigold.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: PettiColors.midnight.withValues(alpha: 0.06),
                blurRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(PettiColors.midnight),
                  ),
                )
              else
                // Always render the pulsing red live-dot, both idle and
                // active. The design treats this as a constant
                // "live-ready" indicator on the primary action.
                const _LivePulseDot(),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isAwaitingDevice
                      ? 'Esperando al collar…'
                      : (isLoading ? 'Cambiando…' : 'En vivo'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PettiColors.midnight,
                    letterSpacing: -0.01 * 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing red "live" indicator — the small red dot with an animated
/// halo that signals real-time streaming. Matches the design's
/// keyframes petti-pulse (scale 0.6→2.4, opacity 0.85→0).
class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot();

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value;
              return Container(
                width: 14 * (0.6 + 1.8 * t),
                height: 14 * (0.6 + 1.8 * t),
                decoration: BoxDecoration(
                  color: PettiColors.alert.withValues(alpha: 0.85 * (1 - t)),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: PettiColors.alert,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: PettiColors.alert.withValues(alpha: 0.25),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _HistorialSecondaryButton — cream secondary action. Toggles between
// "Historial" (when the trail is hidden) and "Cerrar" (when it's shown).
// -----------------------------------------------------------------------------
class _HistorialSecondaryButton extends StatelessWidget {
  final bool showHistory;
  final VoidCallback onTap;

  const _HistorialSecondaryButton({
    required this.showHistory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PettiColors.cloud,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PettiColors.borderLight),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showHistory ? Icons.close_rounded : Icons.history_rounded,
                size: 18,
                color: PettiColors.midnight,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  showHistory ? 'Cerrar' : 'Historial',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PettiColors.midnight,
                    letterSpacing: -0.005 * 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
