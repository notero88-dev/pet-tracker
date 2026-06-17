// MapaTab — the Mapa tab of the bottom-nav root.
//
// For v1 this is a thin reuse of the existing DeviceDetailScreen, which
// already implements the full live-map experience the design specs
// (Google Map fullscreen + pet picker pill + bottom info card + LIVE /
// historial action row). The design's main-tabs.jsx MapaScreen is an
// idealized recreation of what DeviceDetailScreen already does — no
// reason to rewrite.
//
// Behavior when the user has no devices yet: show the empty/onboarding
// affordance (mirrors what HomeScreen already does).
//
// Future polish (not in this commit):
//   - Map sheet: rename "LIVE" → "En vivo", make the En vivo pill
//     prominent (marigold filled, pulsing red dot), remove Compartir
//   - Right-edge zoom/recenter buttons (today the map has its own
//     Google Maps controls baked into the GoogleMap widget)
//   - Pet picker pill at the top of the map (today the screen is
//     single-pet; the picker arrives when multi-pet support lands)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/traccar_provider.dart';
import '../../utils/petti_theme.dart';
import '../device/device_detail_screen.dart';
import '../onboarding/redesign/onboarding_flow_controller.dart';

class MapaTab extends StatefulWidget {
  const MapaTab({super.key});

  @override
  State<MapaTab> createState() => _MapaTabState();
}

class _MapaTabState extends State<MapaTab> {
  // 2026-05-22: lifted from a previous StatelessWidget to support a
  // pet-picker chip row when the user has multiple devices. The index
  // is stored by Traccar device id (int) rather than position so a
  // reordered TraccarProvider list (e.g. after a refetch) doesn't
  // accidentally switch which pet is shown. Falls back to the first
  // device when the stored id isn't in the current list (deleted
  // device, account swap, etc.).
  int? _selectedDeviceId;

  @override
  Widget build(BuildContext context) {
    return Consumer<TraccarProvider>(
      builder: (context, traccar, _) {
        // Show the loading state until the post-login bootstrap has
        // actually finished its first device-load. Gating only on
        // `isLoading` was not enough: at first frame (before connect()
        // runs) isLoading is false AND devices is empty, so the empty
        // state flashed on every cold launch before the map appeared.
        // `initialLoadComplete` closes that window — the empty state now
        // only renders once we KNOW the account has no devices.
        if (!traccar.initialLoadComplete || traccar.isLoading) {
          return const _MapaLoading();
        }
        if (traccar.devices.isEmpty) {
          return _MapaEmptyState();
        }
        final selected = traccar.devices.firstWhere(
          (d) => d.id == _selectedDeviceId,
          orElse: () => traccar.devices.first,
        );
        return DeviceDetailScreen(
          // ValueKey forces a fresh State object on switch so the new
          // device's WebSocket subscription, position cache, and
          // controllers boot from scratch instead of inheriting the
          // previous pet's stale state.
          key: ValueKey(selected.id),
          device: selected,
          showBackButton: false,
          allDevices: traccar.devices,
          onSwitchDevice: (d) => setState(() => _selectedDeviceId = d.id),
        );
      },
    );
  }
}

/// Branded loading state shown while the post-login bootstrap resolves
/// the user's devices. Replaces the bare default-blue spinner so the
/// cold-launch transition into Mapa stays on-palette (marigold on cloud).
class _MapaLoading extends StatelessWidget {
  const _MapaLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: PettiColors.cloud,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(PettiColors.marigold),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Cargando tu mascota…',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: PettiColors.trail,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapaEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: PettiColors.marigoldSoft,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.place_outlined,
                size: 40,
                color: PettiColors.marigoldDim,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aún no hay mascotas',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: PettiColors.midnight,
                letterSpacing: -0.02 * 22,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Empareja un Tracker o agrega un perfil sin dispositivo para verlo en el mapa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: PettiColors.trail,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OnboardingFlowController(),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar mascota'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PettiColors.marigold,
                foregroundColor: PettiColors.midnight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
