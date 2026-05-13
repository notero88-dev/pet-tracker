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

class MapaTab extends StatelessWidget {
  const MapaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TraccarProvider>(
      builder: (context, traccar, _) {
        if (traccar.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (traccar.devices.isEmpty) {
          return _MapaEmptyState();
        }
        // V1: single-device. Take the first one.
        return DeviceDetailScreen(device: traccar.devices.first);
      },
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
