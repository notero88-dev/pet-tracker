// A4.4 — Pareado / "Listo. Tu Petti dijo hola."
//
// Sabana ring-burst around a checkmark, identifier + firmware version,
// 2-up status grid (Hardware / Batería). Source: design package
// screens-a4.jsx::A4_Paired.

import 'package:flutter/material.dart';

import '../../../utils/petti_theme.dart';
import '../../../widgets/petti/petti_cta_dock.dart';
import '../../../widgets/petti/petti_pulse_rings.dart';
import '../../../widgets/petti/petti_screen_heading.dart';
import '../../../widgets/petti/petti_step_header.dart';

class A4PairedScreen extends StatelessWidget {
  /// Device identifier — typically `P-${imei}` formatted by the caller.
  final String identifier;

  /// Firmware version, e.g. "2.4.1".
  final String firmwareVersion;

  /// Current device battery level, 0..100. Default 94 matches the
  /// design's reference value.
  final int batteryPercent;

  /// "Continuar" → caller advances into A5 (GPS fix flow).
  final VoidCallback onContinue;

  const A4PairedScreen({
    super.key,
    required this.identifier,
    this.firmwareVersion = '2.4.1',
    this.batteryPercent = 94,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.midnight,
      body: SafeArea(
        child: Column(
          children: [
            const PettiStepHeader(step: 4, total: 4),
            const Expanded(
              child: Center(
                child: PettiPulseRings(
                  coreSize: 80,
                  step: 50,
                  rings: 3,
                  accent: PettiColors.sabana,
                  child: Icon(Icons.check_rounded,
                      color: PettiColors.fgOnDark, size: 36),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: PettiSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PettiScreenHeading(
                    kicker: 'Pareado',
                    title: 'Listo. Tu Petti dijo hola.',
                    lede: RichText(
                      text: TextSpan(
                        style: PettiText.lead().copyWith(
                          color: PettiColors.fgOnDarkDim,
                          fontSize: 15,
                        ),
                        children: [
                          const TextSpan(text: 'Identificador '),
                          TextSpan(
                            text: identifier,
                            style: PettiText.number(size: 15)
                                .copyWith(color: PettiColors.fgOnDark),
                          ),
                          TextSpan(
                              text:
                                  '\nVersión de firmware $firmwareVersion · todo en orden.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s4),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(label: 'Hardware', value: 'OK'),
                      ),
                      const SizedBox(width: PettiSpacing.s2),
                      Expanded(
                        child: _StatCard(
                          label: 'Batería',
                          value: '$batteryPercent%',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: PettiSpacing.s5),
            PettiCtaDock(primaryLabel: 'Continuar', onPrimary: onContinue),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: PettiSpacing.s4, vertical: PettiSpacing.s3),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
        border: Border.all(color: PettiColors.fgOnDarkHairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: PettiText.meta().copyWith(
              color: PettiColors.fgOnDarkFaint,
              fontSize: 10,
              letterSpacing: 0.05 * 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: PettiText.number(size: 18).copyWith(
              color: PettiColors.fgOnDark,
              letterSpacing: -0.02 * 18,
            ),
          ),
        ],
      ),
    );
  }
}
