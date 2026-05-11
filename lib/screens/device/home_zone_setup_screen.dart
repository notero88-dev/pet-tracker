// HomeZoneSetupScreen — phone-side home-zone setup, Phase B of
// docs/plans/2026-05-11-phone-side-home-zone.md.
//
// Captures the user's home WiFi BSSID + phone GPS + radius, then
// drives the same Mode8ConfigurationController used by the
// onboarding A-flow to program the MT710 (AP / GEO / MODE,8 / LEP).
//
// Two entry points planned:
//   1. Settings → Dispositivo → "Configurar zona de casa"
//      (re-run setup later: user moved house, changed routers, etc.)
//   2. Onboarding A-flow (replaces the device-side SCAN step)
//      — wired in a follow-up; for now the A-flow keeps using SCAN.
//
// What the screen does, in order:
//   1. Requests location permission (BSSID is gated behind it on iOS).
//   2. Reads connected SSID + BSSID via network_info_plus.
//   3. Reads phone GPS via the `location` package.
//   4. Shows a confirmation card with SSID + a radius slider.
//   5. On Continue: validates accuracy <= radius/2 (else "muévete cerca
//      de una ventana"), then drives Mode8ConfigurationController which
//      POSTs the intent and polls until terminal.
//   6. On success: snackbar + pop back. On failure: error UI with retry.
//
// Replaces the throwaway WifiProbeScreen used during Phase A
// verification. Delete that file when this ships.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:location/location.dart' as loc;
import 'package:network_info_plus/network_info_plus.dart';

import '../../models/device.dart';
import '../../services/mode8_configuration_controller.dart';
import '../../utils/petti_theme.dart';

class HomeZoneSetupScreen extends StatefulWidget {
  final Device device;
  final String petName;

  /// Optional initial radius — Settings entry remembers the previous
  /// value via the pet's stored home_ssid; onboarding starts at the
  /// default of 70 m.
  final int initialRadiusMeters;

  const HomeZoneSetupScreen({
    super.key,
    required this.device,
    required this.petName,
    this.initialRadiusMeters = 70,
  });

  @override
  State<HomeZoneSetupScreen> createState() => _HomeZoneSetupScreenState();
}

class _HomeZoneSetupScreenState extends State<HomeZoneSetupScreen> {
  final _networkInfo = NetworkInfo();
  final _location = loc.Location();

  bool _loadingScan = true;
  bool _submitting = false;
  String? _scanError;
  String? _submitError;

  // Captured from the phone.
  String? _ssid;
  String? _bssid;
  double? _lat;
  double? _lng;
  double? _gpsAccuracyMeters;

  // User-tunable.
  late int _radiusMeters = widget.initialRadiusMeters;

  // Mictrack DEF/GEO supports 30–300 m. UI clamps to that.
  static const int _minRadius = 30;
  static const int _maxRadius = 300;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loadingScan = true;
      _scanError = null;
    });
    try {
      // Location permission gates BSSID even with the wifi-info
      // entitlement (iOS policy). Request explicitly.
      var perm = await _location.hasPermission();
      if (perm == loc.PermissionStatus.denied) {
        perm = await _location.requestPermission();
      }
      if (perm != loc.PermissionStatus.granted &&
          perm != loc.PermissionStatus.grantedLimited) {
        setState(() {
          _loadingScan = false;
          _scanError = 'Necesitamos acceso a tu ubicación para detectar '
              'tu red Wi-Fi. Actívalo en Ajustes → Petti → Ubicación.';
        });
        return;
      }
      if (!await _location.serviceEnabled()) {
        final ok = await _location.requestService();
        if (!ok) {
          setState(() {
            _loadingScan = false;
            _scanError = 'Los servicios de ubicación están desactivados '
                'en el sistema. Actívalos en Ajustes.';
          });
          return;
        }
      }

      // Read WiFi + GPS in parallel.
      final ssid = await _networkInfo.getWifiName(); // returns quoted on iOS
      final bssid = await _networkInfo.getWifiBSSID();
      final fix = await _location.getLocation();

      if (bssid == null ||
          bssid == '02:00:00:00:00:00' ||
          ssid == null) {
        setState(() {
          _loadingScan = false;
          _scanError = 'No pudimos leer tu red Wi-Fi. Asegúrate de '
              'estar conectado a tu red de casa y vuelve a intentar.';
        });
        return;
      }

      setState(() {
        _loadingScan = false;
        // iOS wraps SSID in quotes — strip for display.
        _ssid = ssid.replaceAll('"', '');
        _bssid = bssid;
        _lat = fix.latitude;
        _lng = fix.longitude;
        _gpsAccuracyMeters = fix.accuracy;
      });
    } catch (e) {
      setState(() {
        _loadingScan = false;
        _scanError = 'Error al leer tu red y ubicación: $e';
      });
    }
  }

  bool get _gpsIsAccurateEnough {
    // Refuse if GPS accuracy is worse than half the radius — the home
    // zone would be uselessly wide. Plan §"Open questions to settle":
    // require position.accuracy <= radius/2.
    if (_gpsAccuracyMeters == null) return false;
    return _gpsAccuracyMeters! <= _radiusMeters / 2;
  }

  Future<void> _submit() async {
    if (_ssid == null || _bssid == null || _lat == null || _lng == null) {
      return;
    }
    if (!_gpsIsAccurateEnough) {
      setState(() {
        _submitError = 'Tu ubicación no es lo suficientemente precisa '
            '(${_gpsAccuracyMeters!.toStringAsFixed(0)} m). Intenta cerca '
            'de una ventana o aumenta el radio.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final controller = Mode8ConfigurationController(
      device: widget.device,
      petName: widget.petName,
      homeCenter: LatLng(_lat!, _lng!),
      radiusMeters: _radiusMeters,
      homeBssid: _bssid,
      homeSsid: _ssid,
    );

    try {
      final outcome = await controller.run(context);
      if (!mounted) return;
      if (outcome is Mode8WizardSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zona de casa configurada: $_ssid')),
        );
        Navigator.pop(context, true);
      } else if (outcome is Mode8WizardQueued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se aplicará cuando tu mascota se mueva.'),
          ),
        );
        Navigator.pop(context, true);
      } else if (outcome is Mode8WizardError) {
        setState(() {
          _submitting = false;
          _submitError = outcome.userMessage;
        });
      } else if (outcome is Mode8WizardCancelled) {
        setState(() => _submitting = false);
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _submitError = 'Error inesperado: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(title: const Text('Configurar zona de casa')),
      body: SafeArea(
        child: _loadingScan
            ? const Center(child: CircularProgressIndicator())
            : _scanError != null
                ? _ErrorView(message: _scanError!, onRetry: _scan)
                : _ReadyForm(
                    ssid: _ssid!,
                    bssid: _bssid!,
                    gpsAccuracy: _gpsAccuracyMeters!,
                    radius: _radiusMeters,
                    minRadius: _minRadius,
                    maxRadius: _maxRadius,
                    onRadiusChanged: (r) => setState(() => _radiusMeters = r),
                    submitting: _submitting,
                    submitError: _submitError,
                    gpsIsAccurateEnough: _gpsIsAccurateEnough,
                    onRescan: _scan,
                    onSubmit: _submit,
                  ),
      ),
    );
  }
}

class _ReadyForm extends StatelessWidget {
  final String ssid;
  final String bssid;
  final double gpsAccuracy;
  final int radius;
  final int minRadius;
  final int maxRadius;
  final ValueChanged<int> onRadiusChanged;
  final bool submitting;
  final String? submitError;
  final bool gpsIsAccurateEnough;
  final VoidCallback onRescan;
  final VoidCallback onSubmit;

  const _ReadyForm({
    required this.ssid,
    required this.bssid,
    required this.gpsAccuracy,
    required this.radius,
    required this.minRadius,
    required this.maxRadius,
    required this.onRadiusChanged,
    required this.submitting,
    required this.submitError,
    required this.gpsIsAccurateEnough,
    required this.onRescan,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(PettiSpacing.s5),
      children: [
        Text(
          'Tu mascota dormirá tranquila en casa cuando estés conectado '
          'a esta red Wi-Fi.',
          style: PettiText.body(),
        ),
        const SizedBox(height: PettiSpacing.s5),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(PettiSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wifi, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conectado a:',
                            style: PettiText.meta(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ssid,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: submitting ? null : onRescan,
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PettiSpacing.s5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PettiSpacing.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TAMAÑO DE LA ZONA',
                style: PettiText.meta(),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: radius.toDouble(),
                      min: minRadius.toDouble(),
                      max: maxRadius.toDouble(),
                      divisions: (maxRadius - minRadius) ~/ 10,
                      label: '${radius}m',
                      onChanged: submitting
                          ? null
                          : (v) => onRadiusChanged(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${radius}m',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Text(
                'Recomendado: 70 m para apartamentos, '
                'hasta 150 m para casas con jardín.',
                style: PettiText.body().copyWith(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PettiSpacing.s5),
        if (!gpsIsAccurateEnough)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Text(
              'Tu ubicación tiene una precisión de '
              '${gpsAccuracy.toStringAsFixed(0)} m, mayor a la mitad del '
              'radio (${(radius / 2).round()} m). Acércate a una ventana '
              'o aumenta el radio para continuar.',
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
        if (submitError != null) ...[
          const SizedBox(height: PettiSpacing.s4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Text(
              submitError!,
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
        const SizedBox(height: PettiSpacing.s6),
        ElevatedButton(
          onPressed: (submitting || !gpsIsAccurateEnough) ? null : onSubmit,
          child: submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Configurar zona'),
        ),
        const SizedBox(height: PettiSpacing.s5),
        Text(
          'BSSID: $bssid · Precisión GPS: ${gpsAccuracy.toStringAsFixed(0)} m',
          style: PettiText.body().copyWith(
            fontSize: 11,
            color: Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PettiSpacing.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: PettiSpacing.s4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: PettiText.body(),
          ),
          const SizedBox(height: PettiSpacing.s5),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
