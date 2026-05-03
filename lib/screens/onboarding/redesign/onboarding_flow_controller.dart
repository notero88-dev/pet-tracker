// OnboardingFlowController — orchestrates the full A4 → A6 onboarding
// using the redesigned screens. Owns the linear sequence, the cross-
// screen payload (IMEI, pet profile, device, home location, radius),
// and the navigation glue that hands each screen its callback.
//
// Sequence (post-2026-05-03 cutover):
//   A4.1 Intro
//     → A4.2 QR scan  ── (or fallback) → A4.3 Manual IMEI
//                                          ↘
//   A4.4 Paired
//     → A4.5 Pet profile (NEW — name + species)
//        → (provisionDevice — POST /provision)
//        → (resolve phone GPS, brief loader)
//        → A6.1 Pick location
//           → A6.2 Set radius
//              → A6.3 Configuring (NEW — drives Mode8ConfigurationController)
//                 → A6.5 Done    on success
//                 → A6.4 Queued  on QUEUED_EXPIRED
//                 → error UI     on hard failure (back to home)
//
// Why pet profile lives in A4.5 not earlier:
//   provisionDevice() requires petName + petType to insert into the
//   pets table. The legacy onboarding collected this in a separate
//   pet-profile screen before scanning; the redesigned A4 (intro/QR/
//   manual/paired) doesn't have that step. Adding it as A4.5 keeps the
//   flow short while making the provisionDevice call possible.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:provider/provider.dart';

import '../../../models/device.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/provisioning_api.dart';
import '../../home/home_screen.dart';
import '../../../utils/petti_theme.dart';
import 'a4_intro_screen.dart';
import 'a4_manual_imei_screen.dart';
import 'a4_paired_screen.dart';
import 'a4_pet_profile_screen.dart';
import 'a4_qr_scan_screen.dart';
import 'a6_configuring_screen.dart';
import 'a6_done_screen.dart';
import 'a6_pick_location_screen.dart';
import 'a6_queued_screen.dart';
import 'a6_set_radius_screen.dart';

/// Default initial map center when phone GPS is unavailable / denied /
/// timed-out. Bogotá (Plaza de Bolívar).
const LatLng _kDefaultColombiaCenter = LatLng(4.7110, -74.0721);

/// Phone GPS resolution timeout for setting A6 Pick Location's initial
/// camera frame.
const Duration _kPhoneFixTimeout = Duration(seconds: 6);

/// Cross-screen state collected as the user advances through onboarding.
class OnboardingPayload {
  String? imei;
  String? petName;
  PetSpecies? petSpecies;
  Device? device;             // populated by provisionDevice
  LatLng? homeCenter;
  int? homeRadiusMeters;
}

class OnboardingFlowController extends StatefulWidget {
  /// Optional pet name pre-filled from earlier flow. Defaults are
  /// overwritten by what the user types in A4.5 Pet Profile.
  final String? initialPetName;

  const OnboardingFlowController({
    super.key,
    this.initialPetName,
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
    _payload.petName = widget.initialPetName;
  }

  @override
  Widget build(BuildContext context) {
    return A4IntroScreen(
      onContinue: () => _go(_qrScan()),
      onNotYet: () => Navigator.of(context).pop(),
    );
  }

  // ─── Navigation helpers ────────────────────────────────────────────

  void _go(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _replace(Widget screen) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => screen));
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
      onContinue: () => _replace(_petProfile()),
    );
  }

  // ─── A4.5 Pet profile (NEW) ────────────────────────────────────────

  Widget _petProfile() {
    return A4PetProfileScreen(
      onSubmit: (name, species) {
        _payload.petName = name;
        _payload.petSpecies = species;
        _provisionAndAdvance();
      },
      onBack: () => _replace(_paired()),
    );
  }

  // ─── Provisioning step (NEW) ───────────────────────────────────────
  //
  // After pet profile is captured, POST /provision to create the
  // backend Device + Traccar device. On success, _payload.device is
  // populated and the wizard advances to A6 Pick Location. On failure,
  // surface inline error + let user retry.

  Future<void> _provisionAndAdvance() async {
    final overlay = _showOverlay('Registrando a tu Petti...');
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;
      if (user == null || user.email == null) {
        overlay.remove();
        if (!mounted) return;
        _showError(
          'Necesitas estar logueado para configurar a tu Petti.',
          () => _replace(_petProfile()),
        );
        return;
      }

      final api = ProvisioningApi();
      final device = await api.provisionDevice(
        imei: _payload.imei!,
        name: _payload.petName!,
        userId: user.uid,
        userEmail: user.email!,
        petName: _payload.petName!,
        petType: _payload.petSpecies == PetSpecies.dog ? 'dog' : 'cat',
      );
      _payload.device = device;
      overlay.remove();
      if (!mounted) return;

      // Now resolve phone GPS for A6 Pick Location's initial center.
      final initial = await _resolvePhoneCenter();
      if (!mounted) return;
      _replace(_pickLocation(initial));
    } catch (e) {
      overlay.remove();
      if (!mounted) return;
      _showError(
        'No pudimos registrar a tu Petti. Verifica tu conexión e intenta otra vez.\n\n$e',
        () => _replace(_petProfile()),
      );
    }
  }

  Future<LatLng> _resolvePhoneCenter() async {
    final overlay = _showOverlay('Buscando tu ubicación...');
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
    bool serviceOn = await l.serviceEnabled();
    if (!serviceOn) {
      serviceOn = await l.requestService();
      if (!serviceOn) return null;
    }
    var perm = await l.hasPermission();
    if (perm == loc.PermissionStatus.denied) {
      perm = await l.requestPermission();
    }
    if (perm != loc.PermissionStatus.granted &&
        perm != loc.PermissionStatus.grantedLimited) {
      return null;
    }
    await l.changeSettings(accuracy: loc.LocationAccuracy.balanced);
    final data = await l.getLocation();
    if (data.latitude == null || data.longitude == null) return null;
    return LatLng(data.latitude!, data.longitude!);
  }

  /// Inserts a tiny modal-ish overlay with optional caption. Returns the
  /// entry so the caller can remove it.
  OverlayEntry _showOverlay([String? caption]) {
    final entry = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: ColoredBox(
          color: PettiColors.midnight.withValues(alpha: 0.55),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(PettiColors.cloud),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: PettiSpacing.s3),
                  Text(
                    caption,
                    style: PettiText.bodyStrong()
                        .copyWith(color: PettiColors.cloud, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  void _showError(String message, VoidCallback onDismiss) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Algo salió mal'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDismiss();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
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
        _replace(_configuring());
      },
      onBack: () => Navigator.of(context).pop(),
    );
  }

  Widget _configuring() {
    return A6ConfiguringScreen(
      device: _payload.device!,
      petName: _payload.petName!,
      homeCenter: _payload.homeCenter!,
      radiusMeters: _payload.homeRadiusMeters!,
      onSuccess: (_) => _replace(_done()),
      onQueued: (stepsCompleted) =>
          _replace(_queuedScreen(stepsCompleted: stepsCompleted)),
      onError: (userMessage, detail) {
        _showError(
          '$userMessage.\n\nDetalles: $detail',
          () => _replace(_setRadius(_payload.homeCenter!)),
        );
      },
      onCancelled: _exitToHome,
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

  Widget _queuedScreen({required int stepsCompleted}) {
    return A6QueuedScreen(
      stepsCompleted: stepsCompleted,
      onAcknowledge: _exitToHome,
      onBack: () => Navigator.of(context).pop(),
    );
  }
}
