// Petti onboarding — typographic spine.
//
// Three-part heading combo: optional uppercase "kicker" eyebrow,
// hero title (Space Grotesk 32 / 700, balanced), optional lede (Inter 15).
// Used on every onboarding screen below the step header to anchor the
// content and tell the user where they are in the flow.
//
// Source: design package screens-shared.jsx (ScreenHeading).
// 2026-04-29 design delivery.

import 'package:flutter/material.dart';

import '../../utils/petti_theme.dart';

class PettiScreenHeading extends StatelessWidget {
  /// Optional uppercase eyebrow above the title.
  /// e.g. "Paso 1 · emparejar".
  final String? kicker;

  /// Hero title — fragments are encouraged for warmth
  /// ("En casa. A salvo.").
  final String title;

  /// Optional supporting paragraph. Can be either a String (plain text)
  /// or a TextSpan if the caller needs inline emphasis.
  final Widget? lede;

  /// Convenience: pass plain-text lede instead of a TextSpan.
  final String? ledeText;

  /// Accent color for the kicker. Defaults to Marigold; pass Dusk Rose
  /// for "soft / empathetic edge" states (e.g. "tomando un poquito más").
  final Color? kickerColor;

  /// Render on dark surface (default). Inverts colors for the rare
  /// light-onboarding case.
  final bool dark;

  /// Tighter title cap for narrower hierarchy moments — e.g. heading
  /// inside a glass sheet rather than full-screen hero. Set to true to
  /// drop title from `hero()` (32) to `h1()` (28).
  final bool compact;

  const PettiScreenHeading({
    super.key,
    this.kicker,
    required this.title,
    this.lede,
    this.ledeText,
    this.kickerColor,
    this.dark = true,
    this.compact = false,
  }) : assert(lede == null || ledeText == null,
            'Pass either lede or ledeText, not both');

  @override
  Widget build(BuildContext context) {
    final fg = dark ? PettiColors.fgOnDark : PettiColors.midnight;
    final dim = dark ? PettiColors.fgOnDarkDim : PettiColors.fgDim;

    final titleStyle = (compact ? PettiText.h1() : PettiText.hero())
        .copyWith(color: fg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kicker != null) ...[
          Text(
            kicker!.toUpperCase(),
            style: PettiText.meta().copyWith(
              color: kickerColor ?? PettiColors.marigold,
              fontSize: 11,
              letterSpacing: 0.08 * 11,
            ),
          ),
          const SizedBox(height: PettiSpacing.s3),
        ],
        Text(title, style: titleStyle),
        if (lede != null || ledeText != null) ...[
          const SizedBox(height: PettiSpacing.s3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: lede ??
                Text(
                  ledeText!,
                  style: PettiText.lead().copyWith(color: dim, fontSize: 15),
                ),
          ),
        ],
      ],
    );
  }
}
