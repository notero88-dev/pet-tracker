// A4.1 — "Saca tu Petti de la caja"
//
// Opening pairing screen. Centered PettiPuck with warm marigold glow,
// hero heading + lede below, CTA dock. No back button (first screen
// in flow). Source: design package screens-a4.jsx::A4_Intro.

import 'package:flutter/material.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_puck.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A4IntroScreen extends StatelessWidget {
  /// Tapping the primary CTA — caller advances to A4.2 (QR scan).
  final VoidCallback onContinue;

  /// "Mi Petti aún no llega" — caller routes to a wait/help screen.
  /// When null the secondary text-link is omitted.
  final VoidCallback? onNotYet;

  const A4IntroScreen({
    super.key,
    required this.onContinue,
    this.onNotYet,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: SafeArea(
        child: Column(
          children: [
            const PettiStepHeader(step: 1, total: 4, showBack: false),
            const Expanded(
              child: Center(child: PettiPuck(size: 220)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
              child: PettiScreenHeading(
                kicker: 'Paso 1 · emparejar',
                title: 'Saca tu Besti de la caja.',
                ledeText:
                    'Lo vas a sostener cerca del teléfono. Tenlo a la mano — esto toma menos de un minuto.',
              ),
            ),
            const SizedBox(height: PettiSpacing.s6),
            PettiCtaDock(
              primaryLabel: 'Lo tengo',
              onPrimary: onContinue,
              secondaryLabel: onNotYet == null ? null : 'Mi Besti aún no llega',
              onSecondary: onNotYet,
            ),
          ],
        ),
      ),
    );
  }
}
