// A6.4 — "Tu Petti está dormido. Lo despertaremos cuando se mueva."
//
// Empathetic edge state shown when the wizard's `?queue=true` returned
// 408 (TTL elapsed without device wake), or when a partial-state setup
// got queued. Dusk Rose moon-icon hero + status card showing
// "N de 5 pasos completos". Source: design package
// screens-a6.jsx::A6_Queued.

import 'package:flutter/material.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A6QueuedScreen extends StatelessWidget {
  /// Number of wizard steps that DID complete before the device went
  /// quiet. Renders as "N de 5 pasos completos" — total is fixed at 5
  /// because that's how the wizard is structured (SCAN → AP → GEO →
  /// MODE,8 → Traccar geofence). 0..5.
  final int stepsCompleted;

  /// "Entendido" → caller dismisses (typically back to home / live map).
  final VoidCallback onAcknowledge;

  /// "¿Cómo despierto a mi Petti?" → caller routes to a help screen.
  /// When null the secondary text-link is omitted.
  final VoidCallback? onHelp;

  /// Back-chevron tap.
  final VoidCallback? onBack;

  const A6QueuedScreen({
    super.key,
    required this.stepsCompleted,
    required this.onAcknowledge,
    this.onHelp,
    this.onBack,
  }) : assert(stepsCompleted >= 0 && stepsCompleted <= 5,
            'stepsCompleted must be 0..5');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: SafeArea(
        child: Column(
          children: [
            PettiStepHeader(step: 4, total: 4, onBack: onBack),
            const SizedBox(height: PettiSpacing.s5),
            const SizedBox(height: 200, child: Center(child: _SleepingHero())),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
              child: PettiScreenHeading(
                kicker: 'Tu Besti está dormido',
                title: 'Lo despertaremos cuando se mueva.',
                ledeText:
                    'Está en modo de ahorro. Apenas se mueva o lo lleves al aire libre, terminamos la configuración solos.',
                kickerColor: PettiColors.duskRose,
              ),
            ),
            const SizedBox(height: PettiSpacing.s5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PettiSpacing.s4),
              child: _StatusCard(stepsCompleted: stepsCompleted),
            ),
            const Spacer(),
            PettiCtaDock(
              primaryLabel: 'Entendido',
              onPrimary: onAcknowledge,
              secondaryLabel:
                  onHelp == null ? null : '¿Cómo despierto mi Besti?',
              onSecondary: onHelp,
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepingHero extends StatelessWidget {
  const _SleepingHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 1; i <= 2; i++)
          Container(
            width: (90 + i * 50).toDouble(),
            height: (90 + i * 50).toDouble(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    PettiColors.duskRose.withValues(alpha: 0.5 - i * 0.15),
                width: 1,
              ),
            ),
          ),
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: PettiColors.duskRose.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: PettiColors.duskRose.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.bedtime_rounded,
            color: PettiColors.duskRose,
            size: 32,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final int stepsCompleted;

  const _StatusCard({required this.stepsCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PettiSpacing.s4 + 2),
      decoration: BoxDecoration(
        color: PettiColors.duskSoft,
        borderRadius: BorderRadius.circular(PettiRadii.md + 2),
        border: Border.all(
          color: PettiColors.duskRose.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EN COLA',
                style: PettiText.meta().copyWith(
                  color: PettiColors.duskRose,
                  fontSize: 11,
                  letterSpacing: 0.08 * 11,
                ),
              ),
              Text(
                '$stepsCompleted de 5 pasos completos',
                style: PettiText.number(size: 12)
                    .copyWith(color: PettiColors.fgOnDarkDim),
              ),
            ],
          ),
          const SizedBox(height: PettiSpacing.s3),
          Text(
            'Te avisaremos en cuanto el dispositivo despierte. Puedes cerrar la app — esto sigue trabajando solo.',
            style: PettiText.bodySm().copyWith(
              color: PettiColors.fgOnDark.withValues(alpha: 0.78),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
