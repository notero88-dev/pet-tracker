// Petti Design System — tokens + typography helpers
//
// Scope-contained. This does NOT replace AppTheme globally. New Petti-branded
// screens (Device Settings, Zona Segura wizard) reference these tokens
// directly. When we're ready to re-skin the whole app, we can swap
// AppTheme.lightTheme to pull from here.
//
// Colors, typography, and spacing match the Figma/React prototype delivered
// 2026-04-23 (see Downloads/Petti - First design App V1/).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color palette. Names mirror the CSS variables from styles/colors_and_type.css.
class PettiColors {
  // Primary
  static const Color marigold = Color(0xFFE8A33D); // brand, CTAs, selected
  static const Color midnight = Color(0xFF0E1B2C); // primary text, headings
  static const Color cloud = Color(0xFFFAF7F2); // default background

  static const Color marigoldBright = Color(0xFFF2B457);
  static const Color marigoldDim = Color(0xFFC4841F);
  static Color marigoldSoft = const Color(0xFFE8A33D).withValues(alpha: 0.14);

  // Secondary
  static const Color sabana = Color(0xFF2F6B5C); // safe-zone, home, OK
  static const Color cafe = Color(0xFF6B4A34); // warmth, editorial
  static const Color duskRose = Color(0xFFC97A6E); // soft accent, empty states

  static Color sabanaSoft = const Color(0xFF2F6B5C).withValues(alpha: 0.15);
  static Color duskSoft = const Color(0xFFC97A6E).withValues(alpha: 0.14);

  // Functional
  static const Color alert = Color(0xFFD7362C); // real emergencies only
  static const Color trail = Color(0xFF8A8F99); // secondary text, map trails
  static const Color fog = Color(0xFFE8E4DE); // dividers, card outlines
  static const Color sand = Color(0xFFF2EEE7); // secondary backgrounds

  static Color alertSoft = const Color(0xFFD7362C).withValues(alpha: 0.10);

  // Foreground
  static const Color fgStrong = midnight; // headings on cloud
  static const Color fg = Color(0xFF2A3645); // body on cloud
  static const Color fgDim = trail; // meta, labels
  static const Color fgFaint = Color(0xFFB4B8C2); // placeholders, disabled

  // Neutral scale
  static const Color n100 = Color(0xFFF2EEE7);
  static const Color n200 = Color(0xFFE8E4DE);
  static const Color n300 = Color(0xFFD3CFC8);
  static const Color n400 = Color(0xFFB4B0A8);

  // Borders
  static Color borderLight = const Color(0xFF0E1B2C).withValues(alpha: 0.08);
  static Color borderLightStrong = const Color(0xFF0E1B2C).withValues(alpha: 0.14);
}

/// Spacing — 8pt grid.
class PettiSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;
}

/// Radii.
class PettiRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;
}

/// Shadows — warm-tinted to match the design system.
class PettiShadows {
  static final List<BoxShadow> elevation1 = [
    BoxShadow(
      color: const Color(0xFF0E1B2C).withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF0E1B2C).withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> elevation2 = [
    BoxShadow(
      color: const Color(0xFF0E1B2C).withValues(alpha: 0.12),
      blurRadius: 40,
      offset: const Offset(0, 12),
    ),
  ];
}

/// Typography — Space Grotesk for display/numbers, Inter for body.
///
/// Font loading: `google_fonts` fetches fonts at runtime and caches them in
/// the app's documents directory on first launch. Works offline after first
/// launch. Pre-bundling is a future optimization.
class PettiText {
  // Display — Space Grotesk, tight letter-spacing.
  static TextStyle displayXL() => GoogleFonts.spaceGrotesk(
        fontSize: 96,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 96,
        height: 1.05,
        color: PettiColors.fgStrong,
      );

  static TextStyle display() => GoogleFonts.spaceGrotesk(
        fontSize: 72,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.015 * 72,
        height: 1.05,
        color: PettiColors.fgStrong,
      );

  static TextStyle h1() => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 28,
        height: 1.1,
        color: PettiColors.fgStrong,
      );

  static TextStyle h2() => GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 22,
        height: 1.1,
        color: PettiColors.fgStrong,
      );

  static TextStyle h3() => GoogleFonts.spaceGrotesk(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 19,
        height: 1.15,
        color: PettiColors.fgStrong,
      );

  static TextStyle h4() => GoogleFonts.spaceGrotesk(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01 * 17,
        height: 1.2,
        color: PettiColors.fgStrong,
      );

  // Body — Inter.
  static TextStyle lead() => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: PettiColors.fg,
      );

  static TextStyle body() => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: -0.005 * 14,
        color: PettiColors.fg,
      );

  static TextStyle bodyStrong() => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
        letterSpacing: -0.005 * 14,
        color: PettiColors.midnight,
      );

  static TextStyle bodySm() => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: PettiColors.fg,
      );

  static TextStyle label() => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: PettiColors.fgDim,
      );

  // Meta — uppercase eyebrow labels.
  static TextStyle meta() => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.06 * 12,
        color: PettiColors.fgDim,
      );

  // Numbers — tabular.
  static TextStyle number({double size = 15, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.01 * size,
        color: PettiColors.midnight,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
