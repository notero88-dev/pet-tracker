// Petti onboarding — step header.
//
// Compact top bar that anchors every onboarding screen: a back chevron
// on the left, a row of progress dots in the middle (current step
// stretched into a pill), and a "N/M" counter on the right.
//
// The expanded current-step pill is the design system's signature
// progress affordance — feels like a heartbeat, not a generic stepper.
//
// Source: design package "Petti Design System.zip" / screens-shared.jsx
// (StepHeader). 2026-04-29 design delivery.

import 'package:flutter/material.dart';

import '../../utils/petti_theme.dart';

class PettiStepHeader extends StatelessWidget {
  /// 1-indexed current step.
  final int step;

  /// Total step count.
  final int total;

  /// Show the back-chevron button. Default true; pass false for the very
  /// first onboarding screen where there's nowhere to go back to.
  final bool showBack;

  /// Optional override for the back-chevron tap. Defaults to
  /// `Navigator.maybePop(context)`.
  final VoidCallback? onBack;

  /// Render on a dark surface (Midnight). Defaults to true to match the
  /// new dark-onboarding design language. Pass false for any rare
  /// light-surface onboarding step.
  final bool dark;

  const PettiStepHeader({
    super.key,
    required this.step,
    required this.total,
    this.showBack = true,
    this.onBack,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? PettiColors.fgOnDark : PettiColors.midnight;
    final muted = dark ? PettiColors.fgOnDarkDim : PettiColors.fgDim;
    final btnBg = dark
        ? const Color(0xFFFAF7F2).withValues(alpha: 0.06)
        : const Color(0xFF0E1B2C).withValues(alpha: 0.05);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s4,
        PettiSpacing.s2,
        PettiSpacing.s4,
        PettiSpacing.s2,
      ),
      child: Row(
        children: [
          // Back chevron
          SizedBox(
            width: 38,
            height: 38,
            child: showBack
                ? Material(
                    color: btnBg,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onBack ?? () => Navigator.maybePop(context),
                      child: Icon(Icons.chevron_left_rounded, color: fg, size: 22),
                    ),
                  )
                : null,
          ),
          // Centered progress dots — the current step expands into a pill.
          Expanded(
            child: Center(
              child: _ProgressDots(step: step, total: total, dark: dark),
            ),
          ),
          // Right-aligned "N/M" counter.
          SizedBox(
            width: 38,
            child: Text(
              '$step/$total',
              textAlign: TextAlign.right,
              style: PettiText.number(size: 11, weight: FontWeight.w500)
                  .copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int step;
  final int total;
  final bool dark;

  const _ProgressDots({
    required this.step,
    required this.total,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = dark
        ? const Color(0xFFFAF7F2).withValues(alpha: 0.18)
        : const Color(0xFF0E1B2C).withValues(alpha: 0.12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isCurrent = i + 1 == step;
        final isFilled = i + 1 <= step;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: AnimatedContainer(
            duration: PettiMotion.std,
            curve: PettiMotion.ease,
            width: isCurrent ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isFilled ? PettiColors.marigold : inactive,
              borderRadius: BorderRadius.circular(PettiRadii.pill),
            ),
          ),
        );
      }),
    );
  }
}
