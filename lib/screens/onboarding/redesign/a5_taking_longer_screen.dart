// A5.3 — "A veces toma su tiempo encontrar el cielo."
//
// Empathetic edge state shown when the GPS-fix wait crosses N seconds
// without a fix. Same visual language as A5.1 but Dusk Rose instead of
// Marigold (the "soft warning, not failure" tone), with two helper
// tip cards. Source: design package screens-a5.jsx::A5_TakingLonger.

import 'package:flutter/material.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_pulse_rings.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A5TakingLongerScreen extends StatelessWidget {
  /// "Seguir esperando" — caller stays on A5.1 to keep waiting.
  final VoidCallback onKeepWaiting;

  /// "Lo intento más tarde" — caller exits to home / saves for later.
  final VoidCallback onTryLater;

  const A5TakingLongerScreen({
    super.key,
    required this.onKeepWaiting,
    required this.onTryLater,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: SafeArea(
        child: Column(
          children: [
            const PettiStepHeader(step: 3, total: 4),
            const SizedBox(height: PettiSpacing.s5),
            const SizedBox(
              height: 200,
              child: Center(
                child: PettiPulseRings(
                  coreSize: 24,
                  step: 60,
                  rings: 2,
                  accent: PettiColors.duskRose,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
              child: PettiScreenHeading(
                kicker: 'Tomando un poquito más',
                title: 'A veces toma su tiempo encontrar el cielo.',
                ledeText:
                    'Tu Petti está conectado, pero todavía no encuentra suficientes satélites. Esto es normal en interiores.',
                kickerColor: PettiColors.duskRose,
              ),
            ),
            const SizedBox(height: PettiSpacing.s5),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: PettiSpacing.s4),
              child: Column(
                children: [
                  _Tip(
                    emoji: '🪟',
                    title: 'Acércalo a una ventana',
                    detail: 'el GPS necesita ver el cielo, no las paredes',
                  ),
                  SizedBox(height: PettiSpacing.s3 - 2),
                  _Tip(
                    emoji: '🚪',
                    title: 'O sal al balcón un momento',
                    detail:
                        'apenas reciba señal seguimos automáticamente',
                  ),
                ],
              ),
            ),
            const Spacer(),
            PettiCtaDock(
              primaryLabel: 'Seguir esperando',
              onPrimary: onKeepWaiting,
              secondaryLabel: 'Lo intento más tarde',
              onSecondary: onTryLater,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String emoji;
  final String title;
  final String detail;

  const _Tip({
    required this.emoji,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: PettiColors.duskSoft,
        borderRadius: BorderRadius.circular(PettiRadii.md - 2),
        border: Border.all(
          color: PettiColors.duskRose.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PettiColors.duskRose.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(PettiRadii.sm),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: PettiSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PettiText.bodyStrong().copyWith(
                    color: PettiColors.fgOnDark,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: PettiText.bodySm().copyWith(
                    color: PettiColors.fgOnDarkDim,
                    fontSize: 12,
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
