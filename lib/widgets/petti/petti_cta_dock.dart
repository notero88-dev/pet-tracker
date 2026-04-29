// Petti onboarding — bottom CTA dock.
//
// Anchors the primary action at the bottom of the screen with a soft
// gradient fade above it so map / hero content can sit underneath
// without visual collision. Optional secondary text-link under the
// primary button for "skip" / "learn more" / "back" affordances.
//
// Source: design package screens-shared.jsx (CtaDock).
// 2026-04-29 design delivery.

import 'package:flutter/material.dart';

import '../../utils/petti_theme.dart';

class PettiCtaDock extends StatelessWidget {
  final String primaryLabel;

  /// Tap handler for the primary CTA. When null AND [primaryLoading] is
  /// false the button renders disabled.
  final VoidCallback? onPrimary;

  /// Show a small spinner inside the primary button instead of disabling
  /// it. The button still ignores taps while loading.
  final bool primaryLoading;

  /// Optional in-flight label that replaces [primaryLabel] while the
  /// button is loading. e.g. "Buscando…".
  final String? loadingLabel;

  /// Optional secondary action — renders as a centered text link below
  /// the primary button.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Use Dusk Rose (`danger`) instead of Marigold for the primary button.
  /// Reserved for soft warning / "lo intento más tarde" / dismiss flows
  /// the design system marks as `danger=true`.
  final bool danger;

  /// Render against a dark surface (default for new onboarding).
  final bool dark;

  const PettiCtaDock({
    super.key,
    required this.primaryLabel,
    this.onPrimary,
    this.primaryLoading = false,
    this.loadingLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.danger = false,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPrimary == null && !primaryLoading;
    final primaryBg = danger ? PettiColors.duskRose : PettiColors.marigold;

    final disabledBg = dark
        ? const Color(0xFFFAF7F2).withValues(alpha: 0.08)
        : const Color(0xFF0E1B2C).withValues(alpha: 0.08);
    final disabledFg = dark
        ? PettiColors.fgOnDarkFaint
        : PettiColors.fgFaint;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? [
              const Color(0xFF0E1B2C).withValues(alpha: 0),
              const Color(0xFF0E1B2C).withValues(alpha: 0.85),
              const Color(0xFF0E1B2C),
            ]
          : [
              const Color(0xFFFAF7F2).withValues(alpha: 0),
              const Color(0xFFFAF7F2).withValues(alpha: 0.92),
              const Color(0xFFFAF7F2),
            ],
      stops: const [0, 0.4, 1],
    );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s4,
        PettiSpacing.s5,
        PettiSpacing.s5 + PettiSpacing.s3, // extra room for home-indicator
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: disabled ? null : (primaryLoading ? null : onPrimary),
              style: ElevatedButton.styleFrom(
                backgroundColor: disabled ? disabledBg : primaryBg,
                foregroundColor:
                    disabled ? disabledFg : PettiColors.midnight,
                disabledBackgroundColor: disabledBg,
                disabledForegroundColor: disabledFg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PettiRadii.md),
                ),
                textStyle: PettiText.bodyStrong().copyWith(
                  fontSize: 16,
                  letterSpacing: -0.01 * 16,
                ),
              ),
              child: primaryLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(PettiColors.midnight),
                          ),
                        ),
                        const SizedBox(width: PettiSpacing.s3),
                        Text(loadingLabel ?? primaryLabel),
                      ],
                    )
                  : Text(primaryLabel),
            ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: PettiSpacing.s2),
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: dark
                    ? PettiColors.fgOnDarkDim
                    : PettiColors.fgDim,
                textStyle: PettiText.body().copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.005 * 14,
                ),
              ),
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
