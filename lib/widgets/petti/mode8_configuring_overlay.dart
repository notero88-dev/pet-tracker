// Mode8ConfiguringOverlay — full-screen "Enseñándole a tu Petti dónde es
// casa." surface, used both in the legacy setup_geofence_screen.dart
// (overlaid on top of the map editor while the wizard runs) and in the
// new redesigned A6ConfiguringScreen (rendered as a standalone screen).
//
// Was originally _Mode8ConfiguringOverlay, private inside
// setup_geofence_screen.dart. Lifted to a public widget on 2026-05-03 so
// the redesigned A4 → A6 onboarding flow can reuse the visual without
// re-implementing it.

import 'package:flutter/material.dart';

import '../../screens/onboarding/mode8_wizard_state.dart';
import '../../utils/petti_theme.dart';
import 'petti_screen_heading.dart';
import 'petti_wizard_timeline.dart';

class Mode8ConfiguringOverlay extends StatelessWidget {
  final Mode8WizardState state;

  /// When true (legacy use), the overlay renders inside a `Positioned.fill`
  /// (sits on top of an existing Stack child). When false (redesigned use),
  /// it's the only child of a Scaffold and renders as a normal screen.
  final bool positioned;

  const Mode8ConfiguringOverlay({
    super.key,
    required this.state,
    this.positioned = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
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
                title: 'Enseñándole a tu Petti dónde es casa.',
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
    );

    return positioned ? Positioned.fill(child: body) : body;
  }
}

/// Sabana-tinted home glyph: concentric rings + house icon.
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
