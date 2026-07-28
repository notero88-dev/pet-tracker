// HomeZoneSetupWizard — 5-step Zona de casa flow.
//
// Pixel-faithful port of the design bundle's `Zona de casa.html`
// (see docs/plans/2026-05-11-phone-side-home-zone.md and the
// `zona-casa-wizard.jsx` source). Drives the same backend path Phase B
// shipped: phone reads WiFi BSSID + GPS, POSTs to the provisioning-api
// home-setup endpoint, Mode8ConfigurationController polls until terminal.
//
// Wizard steps:
//   1. Intro          — hero, battery delta, "Empezar"
//   2. Permission     — Petti-flavored pre-prompt → iOS system sheet
//   3. Locating       — animated dark map → pin + reverse-geocoded chip
//   4. WiFi           — connected SSID card → "Usar esta red"
//   5. Success        — hero, summary, "Volver al inicio"
//   Denied            — error state with instructions to open Settings
//
// Two entry points:
//   - Settings → Dispositivo → Configurar zona de casa
//     (isOnboarding=false: close on success)
//   - Onboarding A-flow after A5 first-fix
//     (isOnboarding=true: pop-to-home on success)

import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:location/location.dart' as loc;
import 'package:network_info_plus/network_info_plus.dart';

import '../../models/device.dart';
import '../../screens/main/petti_main_tabs_screen.dart';
import '../../services/amplitude_service.dart';
import '../../services/mode8_configuration_controller.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/zona_casa_illustrations.dart';

/// Internal wizard step. Numbered 1..5 with a `denied` edge case to
/// mirror the design state machine 1:1.
enum _Step { intro, permission, locating, wifi, success, denied }

/// Outcome of one capture sub-step. Lives only inside the wizard
/// while it threads phone-captured values from Step 3/4 to the POST in
/// Step 4.
class _Capture {
  final String? ssid;
  final String? bssid;
  final double lat;
  final double lng;
  final double? accuracy;
  final String? address; // reverse-geocoded
  final String? addressDetail; // city · neighborhood

  const _Capture({
    this.ssid,
    this.bssid,
    required this.lat,
    required this.lng,
    this.accuracy,
    this.address,
    this.addressDetail,
  });

  _Capture copyWith({
    String? ssid,
    String? bssid,
    double? lat,
    double? lng,
    double? accuracy,
    String? address,
    String? addressDetail,
  }) {
    return _Capture(
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracy: accuracy ?? this.accuracy,
      address: address ?? this.address,
      addressDetail: addressDetail ?? this.addressDetail,
    );
  }
}

class HomeZoneSetupWizard extends StatefulWidget {
  final Device device;
  final String petName;

  /// When true, success step pops everything back to the home screen.
  /// When false (Settings entry), pops the wizard route only.
  final bool isOnboarding;

  const HomeZoneSetupWizard({
    super.key,
    required this.device,
    required this.petName,
    this.isOnboarding = false,
  });

  @override
  State<HomeZoneSetupWizard> createState() => _HomeZoneSetupWizardState();
}

class _HomeZoneSetupWizardState extends State<HomeZoneSetupWizard> {
  _Step _step = _Step.intro;
  _Capture? _capture;
  String? _errorMessage;
  bool _submittingMode8 = false;
  bool _queuedForWake = false;

  // Fixed radius (design dropped the slider, recommendation: 70m default).
  static const int _radiusMeters = 70;

  // Step numbers for the progress bar (1..5; denied uses 0/0 fallback).
  int _stepNumber(_Step s) => switch (s) {
    _Step.intro => 1,
    _Step.permission => 2,
    _Step.locating => 3,
    _Step.wifi => 4,
    _Step.success => 5,
    _Step.denied => 0,
  };

  void _goto(_Step s) {
    if (!mounted) return;
    setState(() {
      _step = s;
      _errorMessage = null;
    });
  }

  void _onExit() {
    if (widget.isOnboarding) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PettiMainTabsScreen()),
        (_) => false,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onBack() {
    if (_step == _Step.intro) {
      _onExit();
    } else if (_step == _Step.denied) {
      _goto(_Step.permission);
    } else {
      _goto(_Step.values[_step.index - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: PettiColors.cloud,
        body: Column(
          children: [
            _WizardHeader(
              stepNumber: _stepNumber(_step),
              totalSteps: 5,
              isDenied: _step == _Step.denied,
              onBack: _onBack,
              onExit: _onExit,
            ),
            Expanded(child: _renderStep()),
          ],
        ),
      ),
    );
  }

  Widget _renderStep() {
    switch (_step) {
      case _Step.intro:
        return _IntroStep(
          onNext: () => _goto(_Step.permission),
          // "Configurar después" — required for Apple Review (reviewers
          // are not at a home with Wi-Fi) AND for real users who first
          // unbox the collar on the street / at the park. In onboarding,
          // skip drops them into the main tabs; from Settings entry,
          // it just dismisses the wizard. Home zone stays reachable
          // later via Cuenta → Mascotas → este collar → "Activar zona".
          onSkip: _onExit,
        );
      case _Step.permission:
        return _PermissionStep(
          onGrant: _onGrantPermission,
          onSkip: () => _goto(_Step.denied),
        );
      case _Step.locating:
        return _LocatingStep(
          existingCapture: _capture,
          onComplete: (cap) {
            _capture = cap;
            _goto(_Step.wifi);
          },
          onScanError: (msg) {
            setState(() => _errorMessage = msg);
            _goto(_Step.denied);
          },
        );
      case _Step.wifi:
        return _WifiStep(
          capture: _capture!,
          submitting: _submittingMode8,
          submitError: _errorMessage,
          onConfirm: _onConfirmWifi,
          onChangeNetwork: _openWifiSettings,
        );
      case _Step.success:
        return _SuccessStep(
          ssid: _capture?.ssid ?? '—',
          address: _capture?.address ?? '—',
          batteryEstimate: '~14 días',
          onDone: _onExit,
          isOnboarding: widget.isOnboarding,
          queuedForWake: _queuedForWake,
        );
      case _Step.denied:
        return _DeniedStep(
          message:
              _errorMessage ??
              'Sin permiso de ubicación precisa no podemos anclar la zona '
                  'de casa. Puedes activarlo desde Ajustes del sistema.',
          onOpenSettings: () => openAppSettings(),
          onBack: _onBack,
        );
    }
  }

  Future<void> _onGrantPermission() async {
    final location = loc.Location();
    try {
      var perm = await location.hasPermission();
      if (perm == loc.PermissionStatus.denied) {
        perm = await location.requestPermission();
      }
      if (perm != loc.PermissionStatus.granted &&
          perm != loc.PermissionStatus.grantedLimited) {
        _goto(_Step.denied);
        return;
      }
      if (!await location.serviceEnabled()) {
        final ok = await location.requestService();
        if (!ok) {
          _goto(_Step.denied);
          return;
        }
      }
      // Permission granted → advance to locating
      _goto(_Step.locating);
    } catch (e) {
      setState(() {
        _errorMessage = 'No pudimos solicitar el permiso: $e';
      });
      _goto(_Step.denied);
    }
  }

  Future<void> _onConfirmWifi() async {
    if (_capture == null || _capture!.bssid == null || _capture!.ssid == null) {
      setState(() {
        _errorMessage = 'No pudimos leer tu red Wi-Fi. Intenta de nuevo.';
      });
      return;
    }
    setState(() {
      _submittingMode8 = true;
      _errorMessage = null;
    });

    final controller = Mode8ConfigurationController(
      device: widget.device,
      petName: widget.petName,
      homeCenter: LatLng(_capture!.lat, _capture!.lng),
      radiusMeters: _radiusMeters,
      homeBssid: _capture!.bssid,
      homeSsid: _capture!.ssid,
    );

    try {
      final outcome = await controller.run(context);
      if (!mounted) return;
      if (outcome is Mode8WizardSuccess) {
        _queuedForWake = false;
        AmplitudeService.instance.track(
          'Home Zone Configured',
          properties: {
            'device_imei': widget.device.uniqueId,
            'radius_meters': _radiusMeters,
            'queued': false,
          },
        );
        _goto(_Step.success);
      } else if (outcome is Mode8WizardQueued) {
        // Device offline / asleep — runner queued the commands.
        // Success screen shows a slightly different message.
        _queuedForWake = true;
        AmplitudeService.instance.track(
          'Home Zone Configured',
          properties: {
            'device_imei': widget.device.uniqueId,
            'radius_meters': _radiusMeters,
            'queued': true,
          },
        );
        _goto(_Step.success);
      } else if (outcome is Mode8WizardError) {
        setState(() {
          _submittingMode8 = false;
          _errorMessage = outcome.userMessage;
        });
      } else {
        // cancelled or unknown — return to wifi step without advancing
        setState(() {
          _submittingMode8 = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submittingMode8 = false;
        _errorMessage = 'Error inesperado: $e';
      });
    }
  }

  Future<void> _openWifiSettings() async {
    // iOS does not let an app switch the user's WiFi network — only
    // open Settings. URL is `App-Prefs:root=WIFI` on older iOS or
    // `prefs:root=WIFI`; both are now disallowed in App Store apps.
    // The legal path is generic Settings.
    await openAppSettings();
  }

  Future<bool> openAppSettings() async {
    // 2026-07-28 (Lote 2.2): was `launchUrl('app-settings:')` — an
    // iOS-only URL scheme that silently no-oped on Android, stranding
    // any Android user who denied location with a dead button. The
    // app_settings plugin opens the right screen on both platforms.
    try {
      await AppSettings.openAppSettings();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Wizard header ────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final bool isDenied;
  final VoidCallback onBack;
  final VoidCallback onExit;

  const _WizardHeader({
    required this.stepNumber,
    required this.totalSteps,
    required this.isDenied,
    required this.onBack,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (stepNumber / totalSteps).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PillIconButton(icon: Icons.chevron_left, onPressed: onBack),
              Text(
                isDenied
                    ? 'PERMISO NECESARIO'
                    : 'PASO ${stepNumber.clamp(1, totalSteps)} DE $totalSteps',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PettiColors.trail,
                  letterSpacing: 0.72, // 0.06em × 12
                ),
              ),
              _PillIconButton(icon: Icons.close, onPressed: onExit),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: PettiMotion.std,
              curve: PettiMotion.ease,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: PettiColors.n200,
                valueColor: AlwaysStoppedAnimation(
                  isDenied ? PettiColors.duskRose : PettiColors.marigold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _PillIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: PettiColors.midnight.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(icon, size: 18, color: PettiColors.midnight),
        ),
      ),
    );
  }
}

// ─── Step 1 · Intro ───────────────────────────────────────────────────

class _IntroStep extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _IntroStep({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // The intro content (illustration + copy + battery card + permission
      // banner + CTA) can exceed the viewport on shorter Android screens or
      // with a large system font scale. A bare Column + Spacer cannot scroll,
      // which stranded the "Empezar" button off-screen with no way to reach it
      // (Android user report, 2026-07-24). Wrap in a scroll view with a
      // min-height + IntrinsicHeight so the Spacer still pins the CTA to the
      // bottom when there is room, but the whole step scrolls when there isn't.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ZonaCasaIntroIllustration(),
                    const SizedBox(height: 22),
                    const Text(
                      'Activa el modo\nZona de casa',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: PettiColors.midnight,
                        letterSpacing: -0.56, // -0.02em × 28
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cuando tu mascota esté en casa, el tracker reconocerá tu red '
                      'Wi-Fi y entrará en bajo consumo. Empieza a rastrear de nuevo '
                      'en cuanto salga.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        color: PettiColors.fg,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _BatteryDeltaRow(),
                    const SizedBox(height: 16),
                    _PermissionPreviewBanner(),
                    const Spacer(),
                    _CtaButton(
                      label: 'Empezar',
                      icon: Icons.home_outlined,
                      onPressed: onNext,
                    ),
                    const SizedBox(height: 8),
                    // Skip option — required so users (and Apple reviewers) who
                    // aren't currently at home can finish onboarding without
                    // being trapped. They can complete this later from Cuenta.
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: PettiColors.fg,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Configurar después',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BatteryDeltaRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PettiColors.midnight.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _BatteryCell(label: 'AHORA', value: '~3 días', muted: true),
          ),
          const Icon(Icons.chevron_right, size: 16, color: PettiColors.trail),
          Expanded(
            child: _BatteryCell(
              label: 'CON ZONA DE CASA',
              value: '~14 días',
              accent: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryCell extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  final bool muted;

  const _BatteryCell({
    required this.label,
    required this.value,
    this.accent = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: PettiColors.trail,
            letterSpacing: 0.8, // 0.08em
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: accent
                ? PettiColors.sabana
                : (muted ? PettiColors.trail : PettiColors.midnight),
            letterSpacing: -0.27,
            decoration: muted ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}

class _PermissionPreviewBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PettiColors.marigold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.signal_cellular_alt,
            size: 16,
            color: PettiColors.marigoldDim,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              const TextSpan(
                text: 'Necesitaremos tu ',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: PettiColors.fg,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: 'ubicación precisa',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PettiColors.midnight,
                    ),
                  ),
                  TextSpan(text: ' y conectarnos a la '),
                  TextSpan(
                    text: 'red Wi-Fi de tu casa',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PettiColors.midnight,
                    ),
                  ),
                  TextSpan(text: '. Solo una vez.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2 · Permission ──────────────────────────────────────────────

class _PermissionStep extends StatelessWidget {
  final VoidCallback onGrant;
  final VoidCallback onSkip;

  const _PermissionStep({required this.onGrant, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const ZonaCasaMapBackground(),
          const SizedBox(height: 18),
          const Text(
            'Permítenos saber\ndónde estás',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: PettiColors.midnight,
              letterSpacing: -0.48,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            const TextSpan(
              text: 'Necesitamos tu ',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: PettiColors.fg,
                height: 1.55,
              ),
              children: [
                TextSpan(
                  text: 'ubicación precisa',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PettiColors.midnight,
                  ),
                ),
                TextSpan(
                  text:
                      ' para anclar el centro de tu casa. Luego escanearemos '
                      'las redes Wi-Fi cercanas — eso es lo que permite que el '
                      'tracker duerma cuando tu mascota esté en casa.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: PettiColors.midnight.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: const [
                _PermissionRow(
                  icon: Icons.location_on_outlined,
                  title: 'Ubicación precisa',
                  sub: 'Para anclar el centro exacto de tu casa',
                ),
                Divider(
                  height: 24,
                  thickness: 1,
                  color: Color.fromRGBO(14, 27, 44, 0.08),
                ),
                _PermissionRow(
                  icon: Icons.wifi,
                  title: 'Wi-Fi de tu casa',
                  sub: 'Reconocer la red para entrar en modo ahorro',
                ),
                Divider(
                  height: 24,
                  thickness: 1,
                  color: Color.fromRGBO(14, 27, 44, 0.08),
                ),
                _PermissionRow(
                  icon: Icons.check,
                  title: 'Solo para esto',
                  sub: 'No rastreamos tu teléfono en segundo plano',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _CtaButton(label: 'Otorgar permiso', onPressed: onGrant),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              'Ahora no',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PettiColors.trail,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: PettiColors.marigold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: PettiColors.marigoldDim),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PettiColors.midnight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: PettiColors.trail,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 3 · Locating ────────────────────────────────────────────────

class _LocatingStep extends StatefulWidget {
  final _Capture? existingCapture;
  final void Function(_Capture) onComplete;
  final void Function(String) onScanError;

  const _LocatingStep({
    required this.existingCapture,
    required this.onComplete,
    required this.onScanError,
  });

  @override
  State<_LocatingStep> createState() => _LocatingStepState();
}

class _LocatingStepState extends State<_LocatingStep> {
  bool _resolved = false;
  String _addressLine1 = 'Buscando tu ubicación…';
  String _addressLine2 = 'Triangulando con GPS y redes cercanas.';
  String? _accuracyLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final location = loc.Location();
    final info = NetworkInfo();

    try {
      // GPS fix
      final fix = await location.getLocation();
      if (!mounted) return;
      if (fix.latitude == null || fix.longitude == null) {
        widget.onScanError('No pudimos obtener tu ubicación.');
        return;
      }

      // WiFi info in parallel with reverse-geocode
      final results = await Future.wait([
        info.getWifiName().catchError((_) => null),
        info.getWifiBSSID().catchError((_) => null),
        _reverseGeocode(fix.latitude!, fix.longitude!),
      ]);

      if (!mounted) return;
      final ssidRaw = results[0] as String?;
      final bssid = results[1] as String?;
      final geo = results[2] as ({String line1, String line2})?;

      if (bssid == null || bssid == '02:00:00:00:00:00' || ssidRaw == null) {
        widget.onScanError(
          'No pudimos leer tu red Wi-Fi. Asegúrate de estar conectado a tu '
          'red de casa y vuelve a intentar.',
        );
        return;
      }

      final ssid = ssidRaw.replaceAll('"', '');
      final capture = _Capture(
        ssid: ssid,
        bssid: bssid,
        lat: fix.latitude!,
        lng: fix.longitude!,
        accuracy: fix.accuracy,
        address: geo?.line1,
        addressDetail: geo?.line2,
      );

      setState(() {
        _resolved = true;
        _addressLine1 = geo?.line1 ?? 'Casa encontrada';
        _addressLine2 =
            geo?.line2 ??
            '${fix.latitude!.toStringAsFixed(5)}, '
                '${fix.longitude!.toStringAsFixed(5)}';
        _accuracyLabel = fix.accuracy != null
            ? '±${fix.accuracy!.toStringAsFixed(0)} m'
            : null;
      });

      // Give the user a moment to see the resolved address chip before
      // auto-advancing. Mirrors the design's 1800ms beat.
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) widget.onComplete(capture);
    } catch (e) {
      if (!mounted) return;
      widget.onScanError('Error al leer tu ubicación: $e');
    }
  }

  Future<({String line1, String line2})?> _reverseGeocode(
    double lat,
    double lng,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      // Best-effort line1: street + number; fall back to thoroughfare.
      final street = (p.street?.isNotEmpty == true)
          ? p.street!
          : [
              p.thoroughfare,
              p.subThoroughfare,
            ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      final line1 = street.isNotEmpty
          ? street
          : (p.name ?? 'Ubicación encontrada');
      final neighborhood = [
        p.subLocality,
        p.locality,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
      final line2 = neighborhood.isNotEmpty ? neighborhood : (p.country ?? '');
      return (line1: line1, line2: line2);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ZonaCasaMapBackground(
                    height: double.infinity,
                    expanded: true,
                    showRing: _resolved,
                  ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: PettiMotion.std,
                      child: _resolved
                          ? _ResolvedPin(key: const ValueKey('pin'))
                          : _PulsePin(key: const ValueKey('pulse')),
                    ),
                  ),
                  if (_resolved)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _AddressChip(
                        line1: _addressLine1,
                        line2: _addressLine2,
                        accuracyLabel: _accuracyLabel,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _resolved ? 'Casa encontrada' : 'Buscando tu ubicación…',
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: PettiColors.midnight,
                letterSpacing: -0.44,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _resolved
                  ? _addressLine2
                  : 'Triangulando con GPS y redes cercanas.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: PettiColors.fg,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePin extends StatefulWidget {
  const _PulsePin({super.key});

  @override
  State<_PulsePin> createState() => _PulsePinState();
}

class _PulsePinState extends State<_PulsePin> with TickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) {
          final value = _ctl.value;
          final scale = 0.5 + value * 2.7;
          final opacity = (1 - value).clamp(0.0, 0.9);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PettiColors.marigold.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: PettiColors.marigold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResolvedPin extends StatelessWidget {
  const _ResolvedPin({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PettiColors.marigold,
        boxShadow: [
          BoxShadow(
            color: PettiColors.marigold.withValues(alpha: 0.28),
            blurRadius: 0,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.home, color: PettiColors.midnight, size: 20),
    );
  }
}

class _AddressChip extends StatelessWidget {
  final String line1;
  final String line2;
  final String? accuracyLabel;

  const _AddressChip({
    required this.line1,
    required this.line2,
    this.accuracyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(17, 26, 43, 0.78),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.1)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 16, color: PettiColors.marigold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line1,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  line2,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color.fromRGBO(250, 247, 242, 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (accuracyLabel != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: PettiColors.sabana.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                accuracyLabel!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: PettiColors.sabana,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Step 4 · WiFi ────────────────────────────────────────────────────

class _WifiStep extends StatelessWidget {
  final _Capture capture;
  final bool submitting;
  final String? submitError;
  final VoidCallback onConfirm;
  final VoidCallback onChangeNetwork;

  const _WifiStep({
    required this.capture,
    required this.submitting,
    required this.submitError,
    required this.onConfirm,
    required this.onChangeNetwork,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            'Conéctate al Wi-Fi\nde tu casa',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: PettiColors.midnight,
              letterSpacing: -0.48,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta es la red que tu tracker buscará para saber que está en casa.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              color: PettiColors.fg,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _ConnectedNetworkCard(
            ssid: capture.ssid ?? '—',
            onChange: onChangeNetwork,
          ),
          if (submitError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PettiColors.alert.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: PettiColors.alert.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                submitError!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: PettiColors.alert,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _CtaButton(
            label: submitting ? 'Configurando…' : 'Usar esta red',
            icon: submitting ? null : Icons.check,
            loading: submitting,
            onPressed: submitting ? null : onConfirm,
          ),
        ],
      ),
    );
  }
}

class _ConnectedNetworkCard extends StatelessWidget {
  final String ssid;
  final VoidCallback onChange;

  const _ConnectedNetworkCard({required this.ssid, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PettiColors.sabana, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PettiColors.sabana.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.wifi,
                  color: PettiColors.sabana,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TU RED ACTUAL',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: PettiColors.trail,
                            letterSpacing: 0.8,
                          ),
                        ),
                        _ConnectedPill(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ssid,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: PettiColors.midnight,
                        letterSpacing: -0.17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        _SignalBars(strength: 4),
                        SizedBox(width: 8),
                        Text(
                          'Señal excelente · Protegida',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: PettiColors.trail,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: PettiColors.midnight.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Guardaremos esta red como tu casa.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      color: PettiColors.fg,
                      height: 1.4,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onChange,
                  child: const Text(
                    'Cambiar red',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: PettiColors.marigoldDim,
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
}

class _ConnectedPill extends StatefulWidget {
  @override
  State<_ConnectedPill> createState() => _ConnectedPillState();
}

class _ConnectedPillState extends State<_ConnectedPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: PettiColors.sabana.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctl,
            builder: (_, __) {
              final phase = (1 - (_ctl.value - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: PettiColors.sabana,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PettiColors.sabana.withValues(
                        alpha: 0.6 * (1 - phase),
                      ),
                      blurRadius: 0,
                      spreadRadius: 4 * phase,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 5),
          const Text(
            'CONECTADO',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: PettiColors.sabana,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int strength; // 1..4
  const _SignalBars({this.strength = 4});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final on = (i + 1) <= strength;
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Container(
            width: 3,
            height: 4.0 + i * 2,
            decoration: BoxDecoration(
              color: on ? PettiColors.midnight : PettiColors.n300,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Step 5 · Success ────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  final String ssid;
  final String address;
  final String batteryEstimate;
  final VoidCallback onDone;
  final bool isOnboarding;

  /// True when the gateway queued the commands because the device was
  /// offline. The config will apply once the tracker next reconnects;
  /// the success screen shows that explicitly instead of pretending
  /// the device is already configured.
  final bool queuedForWake;

  const _SuccessStep({
    required this.ssid,
    required this.address,
    required this.batteryEstimate,
    required this.onDone,
    required this.isOnboarding,
    this.queuedForWake = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const ZonaCasaSuccessIllustration(),
          const SizedBox(height: 22),
          Text(
            // Single H1 regardless of queued vs immediate success — both
            // mean "the home zone has been saved on our side, and either
            // is or will be applied on the device." The body copy below
            // differentiates the two cases.
            'Zona de casa guardada',
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: PettiColors.midnight,
              letterSpacing: -0.56,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            queuedForWake
                ? 'Guardamos tu zona de casa. Se aplicará la próxima vez '
                      'que tu mascota se mueva y el tracker despierte.'
                : 'Tu mascota puede descansar en casa. El tracker se '
                      'despertará en cuanto cruce la puerta.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: PettiColors.fg,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: PettiColors.midnight.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.wifi,
                  label: 'Red de casa',
                  value: ssid,
                ),
                _SummaryRow(
                  icon: Icons.location_on_outlined,
                  label: 'Ubicación',
                  value: address,
                ),
                _SummaryRow(
                  icon: Icons.battery_charging_full,
                  label: 'Batería ahora',
                  value: batteryEstimate,
                  accent: true,
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _CtaButton(
            label: isOnboarding ? 'Ir a inicio' : 'Volver',
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool accent;
  final bool last;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: PettiColors.midnight.withValues(alpha: 0.08),
                ),
              ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: accent ? PettiColors.sabana : PettiColors.trail,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: PettiColors.fg,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accent ? PettiColors.sabana : PettiColors.midnight,
                letterSpacing: -0.14,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Denied state ─────────────────────────────────────────────────────

class _DeniedStep extends StatelessWidget {
  final String message;
  final Future<bool> Function() onOpenSettings;
  final VoidCallback onBack;

  const _DeniedStep({
    required this.message,
    required this.onOpenSettings,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const ZonaCasaDeniedIllustration(),
          const SizedBox(height: 22),
          const Text(
            'Necesitamos tu ubicación',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: PettiColors.midnight,
              letterSpacing: -0.48,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: PettiColors.fg,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: PettiColors.midnight.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CÓMO ACTIVARLO',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PettiColors.trail,
                    letterSpacing: 0.88,
                  ),
                ),
                const SizedBox(height: 10),
                ..._instructions.asMap().entries.map(
                  (entry) =>
                      _InstructionStep(index: entry.key + 1, text: entry.value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _CtaButton(
            label: 'Abrir Ajustes',
            icon: Icons.settings,
            onPressed: () => onOpenSettings(),
          ),
          const SizedBox(height: 10),
          _CtaButton(
            label: 'Volver',
            variant: _CtaVariant.secondary,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }

  // Platform-aware (Lote 2.2): the copy hardcoded "tu iPhone" and iOS
  // menu names, which read as wrong/broken to Android users.
  static final _instructions = Platform.isIOS
      ? const [
          'Abre Ajustes en tu iPhone',
          'Busca "Besti" en la lista',
          'Activa "Ubicación → Mientras uso la app"',
          'Activa "Ubicación precisa"',
        ]
      : const [
          'Abre Ajustes en tu teléfono',
          'Entra a Aplicaciones → Besti → Permisos',
          'Activa "Ubicación → Permitir solo con la app en uso"',
          'Activa "Usar ubicación precisa"',
        ];
}

class _InstructionStep extends StatelessWidget {
  final int index;
  final String text;

  const _InstructionStep({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: PettiColors.marigold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: PettiColors.marigoldDim,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: PettiColors.fg,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared CTA button ───────────────────────────────────────────────

enum _CtaVariant { primary, secondary }

class _CtaButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final _CtaVariant variant;
  final bool loading;

  const _CtaButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = _CtaVariant.primary,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == _CtaVariant.primary;
    final bg = isPrimary ? PettiColors.marigold : Colors.white;
    final fg = isPrimary ? PettiColors.midnight : PettiColors.midnight;
    final border = isPrimary
        ? BorderSide.none
        : BorderSide(color: PettiColors.midnight.withValues(alpha: 0.14));

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: PettiColors.n200,
          disabledForegroundColor: PettiColors.trail,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PettiColors.midnight,
                ),
              )
            else if (icon != null)
              Icon(icon, size: 16, color: fg),
            if (loading || icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: onPressed == null ? PettiColors.trail : fg,
                letterSpacing: -0.075,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
