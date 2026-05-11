// Zona de casa wizard hero illustrations.
//
// Three SVG-based illustrations used across the wizard (steps 1 and 5)
// and the Settings entry card. Designs are 1:1 with the Petti design
// bundle's `Zona de casa.html` (see `zona-casa-wizard.jsx::CasaIntro`,
// `CasaSuccess`, and `ZonaCasaEntryCard`).
//
// Colors reference the existing PettiColors tokens — Marigold, Midnight,
// Sabana, Cafe — so the illustrations stay in lockstep with theme.
//
// Inline SVG via flutter_svg.SvgPicture.string is intentional: keeps the
// art under version control as plain text (diffable, themeable, no
// asset-pipeline bloat) and matches how the design bundle expressed them.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/petti_theme.dart';

/// Hex string for an SVG `fill` / `stroke` attribute.
String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// Intro hero — sand-tinted card with house, glowing WiFi arcs, sleeping
/// dog and Z's. Used in step 1 of the wizard. ~200px tall.
class ZonaCasaIntroIllustration extends StatelessWidget {
  const ZonaCasaIntroIllustration({super.key, this.height = 200});

  final double height;

  @override
  Widget build(BuildContext context) {
    final mid = _hex(PettiColors.midnight);
    final mar = _hex(PettiColors.marigold);
    final cafe = _hex(PettiColors.cafe);
    final trail = _hex(PettiColors.trail);
    final marSoft = _hex(PettiColors.marigold.withValues(alpha: 0.14));

    final svg =
        '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 170" fill="none">
  <!-- house body -->
  <path d="M64 90l50-40 50 40v52a4 4 0 01-4 4H68a4 4 0 01-4-4V90z"
        stroke="$mid" stroke-width="1.5" fill="#ffffff" stroke-linejoin="round"/>
  <!-- door -->
  <path d="M100 146v-26h28v26" stroke="$mid" stroke-width="1.5" fill="$marSoft"/>
  <!-- router inside -->
  <rect x="86" y="100" width="56" height="14" rx="3" fill="$mid"/>
  <circle cx="94" cy="107" r="1.5" fill="$mar"/>
  <circle cx="100" cy="107" r="1.5" fill="${_hex(PettiColors.sabana)}"/>
  <!-- wifi arcs -->
  <path d="M114 84c6-6 14-6 20 0" stroke="$mar" stroke-width="2" stroke-linecap="round"/>
  <path d="M108 78c10-10 22-10 32 0" stroke="$mar" stroke-width="2" stroke-linecap="round" opacity="0.55"/>
  <path d="M102 72c14-14 30-14 44 0" stroke="$mar" stroke-width="2" stroke-linecap="round" opacity="0.28"/>
  <!-- sleeping dog -->
  <ellipse cx="184" cy="142" rx="22" ry="9" fill="$cafe"/>
  <circle cx="170" cy="138" r="8" fill="$cafe"/>
  <path d="M164 136c-2-2 0-5 3-4" stroke="$cafe" stroke-width="3" stroke-linecap="round"/>
  <circle cx="166" cy="137" r="0.8" fill="#ffffff"/>
  <!-- Z's -->
  <text x="156" y="124" font-family="sans-serif" font-weight="700" font-size="11" fill="$trail">z</text>
  <text x="148" y="116" font-family="sans-serif" font-weight="700" font-size="9" fill="$trail" opacity="0.7">z</text>
</svg>''';

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: RadialGradient(
          center: const Alignment(-0.4, 0.3),
          radius: 0.7,
          colors: [
            PettiColors.marigold.withValues(alpha: 0.22),
            PettiColors.sand,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: SvgPicture.string(svg, width: 240, height: 170),
    );
  }
}

/// Success hero — sand-tinted card with house, glowing sabana WiFi arcs,
/// sleeping dog inside, and a circular check badge. Used in step 5.
class ZonaCasaSuccessIllustration extends StatelessWidget {
  const ZonaCasaSuccessIllustration({super.key, this.height = 210});

  final double height;

  @override
  Widget build(BuildContext context) {
    final mid = _hex(PettiColors.midnight);
    final sab = _hex(PettiColors.sabana);
    final cafe = _hex(PettiColors.cafe);
    final marSoft = _hex(PettiColors.marigold.withValues(alpha: 0.14));

    final svg =
        '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 170" fill="none">
  <!-- house -->
  <path d="M64 86l46-36 46 36v54a3 3 0 01-3 3H67a3 3 0 01-3-3V86z"
        stroke="$mid" stroke-width="1.5" fill="#ffffff" stroke-linejoin="round"/>
  <!-- door -->
  <path d="M96 143v-22h24v22" stroke="$mid" stroke-width="1.5" fill="$marSoft"/>
  <!-- sabana wifi arcs (glowing) -->
  <path d="M110 78c6-6 14-6 20 0" stroke="$sab" stroke-width="2" stroke-linecap="round"/>
  <path d="M104 72c10-10 22-10 32 0" stroke="$sab" stroke-width="2" stroke-linecap="round" opacity="0.6"/>
  <path d="M98 66c14-14 30-14 44 0" stroke="$sab" stroke-width="2" stroke-linecap="round" opacity="0.3"/>
  <!-- sleeping dog inside -->
  <ellipse cx="120" cy="138" rx="18" ry="7" fill="$cafe"/>
  <circle cx="108" cy="134" r="7" fill="$cafe"/>
  <circle cx="105" cy="133" r="0.8" fill="#ffffff"/>
  <!-- check badge -->
  <circle cx="166" cy="60" r="20" fill="$sab"/>
  <path d="M157 60l6 6 12-12" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: RadialGradient(
          center: const Alignment(0, 0.2),
          radius: 0.7,
          colors: [
            PettiColors.sabana.withValues(alpha: 0.22),
            PettiColors.sand,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: SvgPicture.string(svg, width: 220, height: 170),
    );
  }
}

/// Denied state illustration — sad face inside a dusk-tinted card.
class ZonaCasaDeniedIllustration extends StatelessWidget {
  const ZonaCasaDeniedIllustration({super.key, this.height = 180});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dusk = _hex(PettiColors.duskRose);

    final svg =
        '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 140" fill="none">
  <circle cx="80" cy="70" r="42" fill="#ffffff" stroke="$dusk" stroke-width="1.5"/>
  <path d="M70 60l20 20M90 60l-20 20" stroke="$dusk" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M44 110c10-8 22-12 36-12s26 4 36 12" stroke="$dusk" stroke-width="1.5" stroke-linecap="round" fill="none"/>
</svg>''';

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: RadialGradient(
          center: const Alignment(0, 0.2),
          radius: 0.7,
          colors: [
            PettiColors.duskRose.withValues(alpha: 0.18),
            PettiColors.sand,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: SvgPicture.string(svg, width: 160, height: 140),
    );
  }
}

/// Compact illustration used inside the Settings entry card (unconfigured
/// state). 78px tall header strip with a small house + 2 wifi arcs.
class ZonaCasaEntryHeader extends StatelessWidget {
  const ZonaCasaEntryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final mid = _hex(PettiColors.midnight);
    final mar = _hex(PettiColors.marigold);
    final marSoft = _hex(PettiColors.marigold.withValues(alpha: 0.14));

    final svg =
        '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 78" preserveAspectRatio="xMidYMid slice" fill="none">
  <path d="M40 56l24-22 24 22v18a2 2 0 01-2 2H42a2 2 0 01-2-2V56z"
        stroke="$mid" stroke-width="1.4" fill="#ffffff" stroke-linejoin="round"/>
  <path d="M56 76v-12h16v12" stroke="$mid" stroke-width="1.4" fill="$marSoft"/>
  <path d="M96 50c6-6 14-6 20 0" stroke="$mar" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M91 44c10-10 24-10 34 0" stroke="$mar" stroke-width="1.8" stroke-linecap="round" opacity="0.55"/>
  <circle cx="106" cy="60" r="2.5" fill="$mar"/>
</svg>''';

    return Container(
      height: 78,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.5, 0.4),
          radius: 0.7,
          colors: [
            PettiColors.marigold.withValues(alpha: 0.22),
            PettiColors.sand,
          ],
        ),
      ),
      child: SvgPicture.string(svg, fit: BoxFit.cover),
    );
  }
}

/// Locating map background — a dark Midnight grid + WiFi-faded street
/// lines, used as the canvas behind the pulse dot / pin in step 3 (and
/// in the permission map preview on step 2).
class ZonaCasaMapBackground extends StatelessWidget {
  const ZonaCasaMapBackground({
    super.key,
    this.height = 180,
    this.expanded = false,
    this.showRing = false,
  });

  final double height;

  /// `expanded` switches to the larger viewport used by Step 3 (taller,
  /// more visible street lines).
  final bool expanded;

  /// When true, draws the dashed marigold ring around the pin position
  /// — used once Step 3 has resolved a fix.
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final mar = _hex(PettiColors.marigold);
    final h = expanded ? 380 : 180;

    final svg =
        '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 $h" preserveAspectRatio="xMidYMid slice" fill="none">
  <defs>
    <pattern id="grid$h" width="28" height="28" patternUnits="userSpaceOnUse">
      <path d="M28 0H0V28" fill="none" stroke="rgba(255,255,255,0.04)" stroke-width="1"/>
    </pattern>
    <radialGradient id="glow$h" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="$mar" stop-opacity="${showRing ? 0.55 : 0.3}"/>
      <stop offset="100%" stop-color="$mar" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="360" height="$h" fill="#13243A"/>
  <rect width="360" height="$h" fill="url(#grid$h)"/>
  <path d="M -20 ${expanded ? 180 : 90} Q 100 ${expanded ? 140 : 70}, 200 ${expanded ? 200 : 100} T 380 ${expanded ? 160 : 80}"
        stroke="rgba(255,255,255,0.09)" stroke-width="${expanded ? 16 : 14}" fill="none" stroke-linecap="round"/>
  <path d="M 90 -20 Q 110 ${expanded ? 160 : 80}, 80 ${expanded ? 400 : 200}"
        stroke="rgba(255,255,255,0.07)" stroke-width="${expanded ? 12 : 10}" fill="none"/>
  <path d="M 260 -10 Q 280 ${expanded ? 160 : 80}, 300 ${expanded ? 400 : 200}"
        stroke="rgba(255,255,255,0.05)" stroke-width="${expanded ? 10 : 9}" fill="none"/>
  ${expanded ? '<path d="M 0 280 Q 120 240, 240 270 T 380 250" stroke="rgba(255,255,255,0.05)" stroke-width="9" fill="none"/>' : ''}
  <circle cx="180" cy="${expanded ? 190 : 92}" r="${expanded ? 90 : 60}" fill="url(#glow$h)"/>
  ${showRing ? '<circle cx="180" cy="${expanded ? 190 : 92}" r="${expanded ? 60 : 44}" fill="none" stroke="$mar" stroke-width="${expanded ? 1.5 : 1}" stroke-dasharray="${expanded ? '4 4' : '3 5'}" opacity="${expanded ? 0.6 : 0.4}"/>' : ''}
</svg>''';

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(expanded ? 22 : 20),
        color: PettiColors.midnight,
      ),
      clipBehavior: Clip.antiAlias,
      child: SvgPicture.string(svg, fit: BoxFit.cover),
    );
  }
}
