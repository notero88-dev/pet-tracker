// A5.1 — "Despertando a tu Petti"
//
// The 30s–5min waiting window for the device to attach to cellular and
// acquire its first GPS fix. Marigold pulse rings + 3-row checklist
// (cellular / GPS / first fix) + soft hint at the bottom. Source:
// design package screens-a5.jsx::A5_Searching.

import 'package:flutter/material.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_pulse_rings.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

enum SearchStepStatus { done, active, pending }

class SearchStep {
  final String label;
  final String detail;
  final SearchStepStatus status;
  const SearchStep({
    required this.label,
    required this.detail,
    required this.status,
  });
}

class A5SearchingScreen extends StatelessWidget {
  /// Live progress of the 3 sub-steps. Caller updates this as the
  /// gateway reports cell-attach → GPS lock → first position frame.
  final List<SearchStep> steps;

  const A5SearchingScreen({super.key, required this.steps});

  /// Convenience constructor for the canonical first-fix sequence.
  factory A5SearchingScreen.canonical({
    required SearchStepStatus cellular,
    required SearchStepStatus gps,
    required SearchStepStatus firstFix,
    String cellularDetail = 'LTE-M · Movistar',
    String gpsDetail = 'buscando satélites',
    String fixDetail = 'esperando…',
  }) {
    return A5SearchingScreen(steps: [
      SearchStep(
        label: 'Conectando con la red móvil',
        detail: cellularDetail,
        status: cellular,
      ),
      SearchStep(
        label: 'Buscando satélites GPS',
        detail: gpsDetail,
        status: gps,
      ),
      SearchStep(
        label: 'Primera ubicación',
        detail: fixDetail,
        status: firstFix,
      ),
    ]);
  }

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
              height: 240,
              child: Center(
                child: PettiPulseRings(
                  coreSize: 28,
                  step: 60,
                  rings: 3,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: PettiSpacing.s5),
              child: PettiScreenHeading(
                title: 'Despertando a tu Petti.',
                ledeText:
                    'A veces toma 30 segundos, a veces hasta 5 minutos. No tengas afán.',
              ),
            ),
            const SizedBox(height: PettiSpacing.s5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PettiSpacing.s4),
              child: _StepList(steps: steps),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PettiSpacing.s5,
                vertical: PettiSpacing.s5,
              ),
              child: Text(
                'Si está cerca de una ventana o al aire libre, encuentra señal más rápido.',
                textAlign: TextAlign.center,
                style: PettiText.bodySm().copyWith(
                  color: PettiColors.fgOnDarkFaint,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  final List<SearchStep> steps;
  const _StepList({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(PettiRadii.md + 2),
        border: Border.all(color: PettiColors.fgOnDarkHairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepRow(step: steps[i]),
            if (i < steps.length - 1)
              Container(
                height: 1,
                color: const Color(0xFFFAF7F2).withValues(alpha: 0.05),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final SearchStep step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final isPending = step.status == SearchStepStatus.pending;
    return Opacity(
      opacity: isPending ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            PettiSpacing.s4, PettiSpacing.s3 + 2, PettiSpacing.s4, PettiSpacing.s3 + 2),
        child: Row(
          children: [
            _StatusDot(status: step.status),
            const SizedBox(width: PettiSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: PettiText.bodyStrong().copyWith(
                      color: isPending
                          ? PettiColors.fgOnDarkDim
                          : PettiColors.fgOnDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.detail,
                    style: PettiText.bodySm().copyWith(
                      color: PettiColors.fgOnDarkFaint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (step.status == SearchStepStatus.active)
              Text(
                'EN CURSO',
                style: PettiText.meta().copyWith(
                  color: PettiColors.marigold,
                  fontSize: 11,
                  letterSpacing: 0.04 * 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final SearchStepStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SearchStepStatus.done:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: PettiColors.sabana,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: PettiColors.fgOnDark, size: 14),
        );
      case SearchStepStatus.active:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: PettiColors.marigoldSoft,
            shape: BoxShape.circle,
            border: Border.all(color: PettiColors.marigold, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: PettiColors.marigold,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case SearchStepStatus.pending:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2).withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
        );
    }
  }
}
