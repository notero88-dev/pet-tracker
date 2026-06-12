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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../models/device.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/amplitude_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/provisioning_api.dart';
import '../../../utils/petti_theme.dart';
import '../../device/home_zone_setup_wizard.dart';
import 'a4_intro_screen.dart';
import 'a4_manual_imei_screen.dart';
import 'a4_paired_screen.dart';
import 'a4_pet_profile_screen.dart';
import 'a4_qr_scan_screen.dart';

/// Default initial map center when phone GPS is unavailable / denied /
/// timed-out. Bogotá (Plaza de Bolívar).
// (Removed _kDefaultColombiaCenter — was the fallback center for the
// legacy A6 PickLocation when phone GPS timed out. The new
// HomeZoneSetupWizard handles GPS failure via the Denied step instead.)

/// Phone GPS resolution timeout for setting A6 Pick Location's initial
/// camera frame.

/// Cross-screen state collected as the user advances through onboarding.
class OnboardingPayload {
  String? imei;
  String? petName;
  PetSpecies? petSpecies;
  File? petPhoto;             // optional local file from A4 pet profile
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

  // _exitToHome removed 2026-05-11 — was used by the legacy A6Done/
  // A6Queued/A6Configuring chain. The new HomeZoneSetupWizard handles
  // post-success navigation itself via its isOnboarding flag.

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
      onSubmit: (name, species, photo) {
        _payload.petName = name;
        _payload.petSpecies = species;
        _payload.petPhoto = photo;
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
    final overlay = _showOverlay('Registrando tu Besti...');
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;
      if (user == null || user.email == null) {
        overlay.remove();
        if (!mounted) return;
        _showError(
          'Necesitas estar logueado para configurar tu Besti.',
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
      AmplitudeService.instance.track('Device Provisioned', properties: {
        'pet_species': _payload.petSpecies == PetSpecies.dog ? 'dog' : 'cat',
        'pairing_method': _payload.imei != null ? 'qr_or_manual' : 'unknown',
      });

      // Create the Firestore pet doc right here (name + species + photo)
      // instead of leaving it to the lazy reconciler in
      // PettiMainTabsScreen. The reconciler only runs after a successful
      // Traccar login on the NEXT cold launch and creates a placeholder
      // with no photo; doing it now means Mascotas/Salud show the real
      // name + photo immediately, and the reconciler then skips this
      // device (it dedupes on traccarDeviceId). Best-effort: a Firestore
      // failure must not abort onboarding — the reconciler is the
      // fallback. (2026-06-11.)
      await _createPetDoc(device);

      overlay.remove();
      if (!mounted) return;

      // Phase B (2026-05-11): replace the A6 pick_location → set_radius
      // → configuring → done chain with the new HomeZoneSetupWizard.
      // The wizard internally captures phone GPS + BSSID (the old
      // _resolvePhoneCenter dance is now inside Step 3), so we don't
      // pre-resolve a center here.
      _replace(_zonaCasaWizard());
    } catch (e) {
      overlay.remove();
      if (!mounted) return;
      _showError(
        'No pudimos registrar tu Besti. Verifica tu conexión e intenta otra vez.\n\n$e',
        () => _replace(_petProfile()),
      );
    }
  }

  /// Create the Firestore pet doc for the just-provisioned device,
  /// uploading the optional photo first. Best-effort: any failure is
  /// swallowed (the PettiMainTabsScreen reconciler is the fallback).
  Future<void> _createPetDoc(Device device) async {
    try {
      final firestore = FirestoreService();
      String? photoUrl;
      final photo = _payload.petPhoto;
      if (photo != null) {
        photoUrl = await firestore.uploadPetPhoto(photo);
      }
      await firestore.createPet(
        name: _payload.petName!,
        type: _payload.petSpecies == PetSpecies.dog ? 'dog' : 'cat',
        photoUrl: photoUrl,
        traccarDeviceId: device.traccarId,
        deviceImei: _payload.imei,
      );
    } catch (_) {
      // Reconciler in PettiMainTabsScreen will create a placeholder on
      // next launch if this didn't land. Don't block onboarding.
    }
  }

  // _resolvePhoneCenter + _tryGetPhoneFix removed 2026-05-11 — Step 3
  // of HomeZoneSetupWizard now handles GPS acquisition internally,
  // with its own permission flow, address chip, and reverse geocoding.
  // The associated constants below (kDefaultColombiaCenter,
  // kPhoneFixTimeout) are no longer referenced; left here as
  // intentional anchors should any future flow need a Colombia-centered
  // fallback.

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

  // ─── A6 → HomeZoneSetupWizard (Phase B, 2026-05-11) ─────────────────
  //
  // The legacy chain (`A6PickLocation → A6SetRadius → A6Configuring →
  // A6Done` / `A6Queued`) is replaced by the new 5-step
  // `HomeZoneSetupWizard`. It captures phone GPS + BSSID itself in
  // Step 3, drives the same Mode8ConfigurationController internally,
  // and exits to the home screen on success (`isOnboarding: true`).
  // The legacy screen files (a6_pick_location_screen.dart etc.) are
  // left on disk for reference but no longer routed.

  Widget _zonaCasaWizard() {
    return HomeZoneSetupWizard(
      device: _payload.device!,
      petName: _payload.petName!,
      isOnboarding: true,
    );
  }
}
