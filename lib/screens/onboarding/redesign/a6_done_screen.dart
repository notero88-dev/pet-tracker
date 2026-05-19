// A6.5 — "[Pet name] está en casa."
//
// Final-success screen of the onboarding flow. Mini-map preview of the
// chosen geofence with Sabana fill, Sabana checkmark badge, hero copy
// using the user's pet name, summary detail row. Source: design package
// screens-a6.jsx::A6_Done.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A6DoneScreen extends StatelessWidget {
  /// The pet's name. Used in the hero "[Pet] está en casa." string.
  final String petName;

  /// Center of the geofence — used to anchor the mini-map preview.
  final LatLng homeCenter;

  /// Radius the user just set, in meters.
  final int radiusMeters;

  /// Optional human-readable address label (e.g. "Casa · Chapinero").
  /// Falls back to "Casa" if not provided.
  final String? addressLabel;

  /// "Ver el mapa" → caller routes to the home/live-tracking screen.
  final VoidCallback onSeeMap;

  /// "Definir otra zona" → caller routes back to A6.1 to add another
  /// geofence (park, vet, grandma's house, etc.). When null the
  /// secondary text-link is omitted.
  final VoidCallback? onDefineAnother;

  const A6DoneScreen({
    super.key,
    required this.petName,
    required this.homeCenter,
    required this.radiusMeters,
    this.addressLabel,
    required this.onSeeMap,
    this.onDefineAnother,
  });

  @override
  Widget build(BuildContext context) {
    final addressLine = addressLabel ?? 'Casa';
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PettiStepHeader(step: 4, total: 4, showBack: false),
            const SizedBox(height: PettiSpacing.s2),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: PettiSpacing.s4),
              child: _MiniMap(
                center: homeCenter,
                radiusMeters: radiusMeters,
              ),
            ),
            const SizedBox(height: PettiSpacing.s5 + 2),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sabana checkmark badge.
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: PettiColors.sabana,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: PettiColors.fgOnDark,
                          size: 9,
                        ),
                      ),
                      const SizedBox(width: PettiSpacing.s2),
                      Text(
                        'ZONA SEGURA ACTIVA',
                        style: PettiText.meta().copyWith(
                          color: PettiColors.sabana,
                          fontSize: 11,
                          letterSpacing: 0.08 * 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PettiSpacing.s3),
                  Text(
                    '$petName está en casa.',
                    style: PettiText.hero().copyWith(
                      color: PettiColors.fgOnDark,
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s3),
                  Text(
                    'Te avisaremos si sale del círculo. Mientras tanto, tu Besti duerme tranquilo y cuida la batería.',
                    style: PettiText.lead().copyWith(
                      color: PettiColors.fgOnDarkDim,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s4 + 2),
                  _DetailRow(
                    addressLabel: addressLine,
                    radiusMeters: radiusMeters,
                  ),
                ],
              ),
            ),
            const Spacer(),
            PettiCtaDock(
              primaryLabel: 'Ver el mapa',
              onPrimary: onSeeMap,
              secondaryLabel:
                  onDefineAnother == null ? null : 'Definir otra zona',
              onSecondary: onDefineAnother,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  final LatLng center;
  final int radiusMeters;
  const _MiniMap({required this.center, required this.radiusMeters});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PettiRadii.lg - 2),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: _zoomFor(radiusMeters.toDouble()),
              ),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              circles: {
                Circle(
                  circleId: const CircleId('home'),
                  center: center,
                  radius: radiusMeters.toDouble(),
                  fillColor: PettiColors.sabana.withValues(alpha: 0.2),
                  strokeColor: PettiColors.sabana,
                  strokeWidth: 1,
                ),
              },
              markers: {
                Marker(markerId: const MarkerId('home-center'), position: center),
              },
            ),
            // Hairline border on top.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFAF7F2).withValues(alpha: 0.06),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(PettiRadii.lg - 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _zoomFor(double radius) {
    if (radius <= 80) return 17.5;
    if (radius <= 150) return 16.8;
    if (radius <= 250) return 16;
    if (radius <= 400) return 15.2;
    return 14.6;
  }
}

class _DetailRow extends StatelessWidget {
  final String addressLabel;
  final int radiusMeters;

  const _DetailRow({
    required this.addressLabel,
    required this.radiusMeters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: PettiSpacing.s4, vertical: PettiSpacing.s3 + 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(PettiRadii.md - 2),
        border: Border.all(color: PettiColors.fgOnDarkHairline, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addressLabel.toUpperCase(),
                  style: PettiText.meta().copyWith(
                    color: PettiColors.fgOnDarkFaint,
                    fontSize: 10,
                    letterSpacing: 0.06 * 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Radio $radiusMeters m · alertas activadas',
                  style: PettiText.bodyStrong().copyWith(
                    color: PettiColors.fgOnDark,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: PettiColors.fgOnDarkFaint, size: 18),
        ],
      ),
    );
  }
}
