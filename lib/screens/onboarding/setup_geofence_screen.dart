// Setup-first-geofence (onboarding) — Petti restyle.
//
// User just got their first GPS fix; this screen lets them drop a circle
// for "Casa" centered on the current position. Map at the top, Petti
// bottom sheet with a name field + radius slider + Marigold "Crear" CTA
// + skip option.
//
// Map circle uses Sabana (safe-zone color) instead of legacy green;
// fixed-position center crosshair becomes a Petti compass marker.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import '../../services/provisioning_api.dart';
import '../../services/wizard_step_result.dart';
import '../../utils/petti_theme.dart';
import '../home/home_screen.dart';
import 'mode8_wizard_state.dart';

class SetupGeofenceScreen extends StatefulWidget {
  final Device device;
  final String petName;
  final Position currentPosition;

  /// Optional ProvisioningApi injection for tests. Production callers
  /// should leave this null and let the screen build its own client.
  final ProvisioningApi? api;

  const SetupGeofenceScreen({
    super.key,
    required this.device,
    required this.petName,
    required this.currentPosition,
    this.api,
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

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ProvisioningApi();
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

    // ---- Step 1: SCAN — collect nearby WiFi APs from the device.
    setState(() => _wizardState = Mode8WizardState.scanning);
    final scanResult = await _api.scan(imei: imei);
    final macs = _parseScanResult(scanResult);
    if (macs == null) {
      _failWizard(scanResult, 'No pudimos leer las redes WiFi de tu casa');
      return;
    }

    // ---- Step 2: AP,,,MAC1,MAC2,MAC3 — register home anchors.
    setState(() => _wizardState = Mode8WizardState.settingMacs);
    final apResult = await _api.setAccessPoints(
      imei: imei,
      mac1: macs[0],
      mac2: macs[1],
      mac3: macs[2],
    );
    if (apResult is! WizardStepOk) {
      _failWizard(apResult, 'No pudimos memorizar tu casa');
      return;
    }

    // ---- Step 3: GEO,LAT,LON,RADIUS — set the home geofence center.
    // We use explicit coordinates (not SEARCH) because we already know
    // the user's chosen location, and SEARCH is unreliable on V2.1.8
    // firmware (PLAN.md Epic 3).
    setState(() => _wizardState = Mode8WizardState.settingHomeZone);
    final geoResult = await _api.setGeoFence(
      imei: imei,
      latitude: _center.latitude,
      longitude: _center.longitude,
      radiusMeters: _radiusMeters.round(),
    );
    if (geoResult is! WizardStepOk) {
      _failWizard(geoResult, 'No pudimos dibujar tu zona segura');
      return;
    }

    // ---- Step 4: MODE,8,30 — enable Home Mode with 30s wake window.
    setState(() => _wizardState = Mode8WizardState.enteringMode8);
    final modeResult = await _api.setModeHome(imei: imei, intervalSeconds: 30);
    if (modeResult is! WizardStepOk) {
      _failWizard(modeResult, 'No pudimos activar el ahorro de batería');
      return;
    }

    // ---- Step 5: server-side Traccar geofence (alert evaluation).
    if (!mounted) return;
    setState(() => _wizardState = Mode8WizardState.creatingTraccarGeofence);
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final geofenceId = await traccar.createCircularGeofence(
      name: name,
      latitude: _center.latitude,
      longitude: _center.longitude,
      radiusMeters: _radiusMeters,
      deviceId: widget.device.traccarId!,
    );
    if (geofenceId == null) {
      _failWizard(
        WizardStepFailed(traccar.errorMessage ?? 'Traccar geofence creation failed'),
        traccar.errorMessage ?? 'No pudimos guardar la zona en el servidor',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _wizardState = Mode8WizardState.success;
      _isCreating = false;
    });
    _showSuccess();
  }

  /// Pick the top 3 MACs from a SCAN reply payload, or fall back to
  /// placeholder MACs when the device returns nothing usable.
  ///
  /// V2.1.8 firmware quirk: SCAN sometimes returns just `"#"` (an empty
  /// list) even when WiFi APs are clearly in range. When that happens
  /// we still register placeholder MACs so the device transitions into
  /// Mode 8 — the GPS geofence (set in step 3) provides the actual
  /// "is at home?" check; the WiFi anchors are a redundant signal that
  /// will simply never match. Once Mictrack clarifies SCAN behavior
  /// (PLAN.md Epic 3) this can be tightened.
  ///
  /// Returns null only if the SCAN call itself didn't return Ok.
  List<String>? _parseScanResult(WizardStepResult result) {
    if (result is! WizardStepOk) return null;
    final raw = result.payload.trim();
    if (raw.isEmpty || raw == '#') {
      return ['000000000001', '000000000002', '000000000003'];
    }
    final parsed = raw
        .split(',')
        .map((e) => e.split(':').first.trim())
        .where((e) => RegExp(r'^[0-9A-Fa-f]{12}$|^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$').hasMatch(e))
        .take(3)
        .toList();
    if (parsed.length < 3) {
      return ['000000000001', '000000000002', '000000000003'];
    }
    return parsed;
  }

  /// Halt the wizard, surface a Spanish-language error, and clear
  /// _isCreating so the user can retry.
  void _failWizard(WizardStepResult result, String userMessage) {
    if (!mounted) return;
    String detail;
    if (result is WizardStepQueueExpired) {
      detail = 'Tu PetTrack no respondió a tiempo. '
          'Llévalo cerca de una ventana o muévelo para despertarlo.';
    } else if (result is WizardStepDeviceOffline) {
      detail = 'No estamos detectando tu PetTrack. Asegúrate de que esté encendido.';
    } else if (result is WizardStepTimedOut) {
      detail = 'Tu PetTrack no terminó de aplicar la configuración. '
          'Inténtalo de nuevo en unos segundos.';
    } else if (result is WizardStepDeviceRejected) {
      detail = 'Tu PetTrack rechazó la orden (${result.payload}). Inténtalo de nuevo.';
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
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }
}
