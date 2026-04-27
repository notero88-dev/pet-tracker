// Petti Design System — tokens + typography + global ThemeData
//
// As of 2026-04-27 this IS the global app theme. `main.dart` plugs
// `PettiTheme.lightTheme` into `MaterialApp.theme`, which means every
// Material widget (TextField, ElevatedButton, AppBar, Scaffold, …)
// inherits Petti colors and Inter/Space-Grotesk typography by default.
// Per-screen code can still reference PettiColors / PettiText directly
// for one-off accents.
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

/// Global ThemeData. Plug into `MaterialApp.theme` so every Material widget
/// inherits Petti colors/type without per-screen overrides.
///
/// The intent is "Material 3 widgets, Petti tokens" — we use M3 as the
/// scaffolding (TextField, ElevatedButton, AppBar, etc.) but every visible
/// surface, color, and font is from the Petti system.
class PettiTheme {
  /// Light theme (the only one we ship today; dark mode is future work).
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: PettiColors.marigold,
      onPrimary: PettiColors.midnight,
      primaryContainer: PettiColors.marigoldSoft,
      onPrimaryContainer: PettiColors.midnight,
      secondary: PettiColors.sabana,
      onSecondary: Colors.white,
      secondaryContainer: PettiColors.sabanaSoft,
      onSecondaryContainer: PettiColors.sabana,
      tertiary: PettiColors.duskRose,
      onTertiary: Colors.white,
      tertiaryContainer: PettiColors.duskSoft,
      onTertiaryContainer: PettiColors.cafe,
      error: PettiColors.alert,
      onError: Colors.white,
      errorContainer: PettiColors.alertSoft,
      onErrorContainer: PettiColors.alert,
      surface: PettiColors.cloud,
      onSurface: PettiColors.fgStrong,
      surfaceContainerHighest: PettiColors.sand,
      onSurfaceVariant: PettiColors.fg,
      outline: PettiColors.borderLightStrong,
      outlineVariant: PettiColors.fog,
      shadow: PettiColors.midnight,
      scrim: PettiColors.midnight,
      inverseSurface: PettiColors.midnight,
      onInverseSurface: PettiColors.cloud,
      inversePrimary: PettiColors.marigoldBright,
    );

    // Material's TextTheme. Sized to match Petti's scale; widgets that pull
    // from Theme.of(context).textTheme.* now get Inter/Space Grotesk for free.
    final textTheme = TextTheme(
      displayLarge: PettiText.displayXL(),
      displayMedium: PettiText.display(),
      displaySmall: PettiText.h1(),
      headlineLarge: PettiText.h1(),
      headlineMedium: PettiText.h2(),
      headlineSmall: PettiText.h3(),
      titleLarge: PettiText.h3(),
      titleMedium: PettiText.h4(),
      titleSmall: PettiText.bodyStrong(),
      bodyLarge: PettiText.lead(),
      bodyMedium: PettiText.body(),
      bodySmall: PettiText.bodySm(),
      labelLarge: PettiText.bodyStrong(),
      labelMedium: PettiText.label(),
      labelSmall: PettiText.meta(),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: PettiColors.cloud,
      canvasColor: PettiColors.cloud,
      dividerColor: PettiColors.fog,
      dividerTheme: const DividerThemeData(
        color: PettiColors.fog,
        thickness: 1,
        space: 1,
      ),

      // App bars — quiet, surface-tinted, matches the screens that use them.
      appBarTheme: AppBarTheme(
        backgroundColor: PettiColors.cloud,
        foregroundColor: PettiColors.fgStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: PettiText.h3(),
        iconTheme: const IconThemeData(color: PettiColors.fgStrong, size: 24),
      ),

      // Bottom nav (used in home_screen.dart). Marigold for selected.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: PettiColors.cloud,
        selectedItemColor: PettiColors.midnight,
        unselectedItemColor: PettiColors.trail,
        selectedLabelStyle: PettiText.label().copyWith(
          fontWeight: FontWeight.w600,
          color: PettiColors.midnight,
        ),
        unselectedLabelStyle: PettiText.label(),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Primary CTA button — Marigold + Midnight. Matches PettiCta in
      // widgets/petti/petti_primitives.dart so screens using either look the
      // same.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PettiColors.marigold,
          foregroundColor: PettiColors.midnight,
          disabledBackgroundColor: PettiColors.n200,
          disabledForegroundColor: PettiColors.fgFaint,
          textStyle: PettiText.bodyStrong().copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s5,
            vertical: PettiSpacing.s4,
          ),
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PettiRadii.md),
          ),
        ),
      ),

      // Secondary / outlined CTA — Midnight outline on Cloud.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PettiColors.midnight,
          side: const BorderSide(color: PettiColors.midnight, width: 1.5),
          textStyle: PettiText.bodyStrong().copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s5,
            vertical: PettiSpacing.s4,
          ),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PettiRadii.md),
          ),
        ),
      ),

      // Text-only button — Midnight, no border.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PettiColors.midnight,
          textStyle: PettiText.bodyStrong(),
          padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s3,
            vertical: PettiSpacing.s2,
          ),
        ),
      ),

      // Form inputs (login, signup, IMEI entry) — soft cream surface,
      // marigold focus ring, alert-red error state.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PettiColors.sand,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PettiSpacing.s4,
          vertical: PettiSpacing.s4,
        ),
        hintStyle: PettiText.body().copyWith(color: PettiColors.fgFaint),
        labelStyle: PettiText.label(),
        floatingLabelStyle: PettiText.label().copyWith(
          color: PettiColors.midnight,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PettiRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PettiRadii.md),
          borderSide: BorderSide(color: PettiColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PettiRadii.md),
          borderSide: const BorderSide(color: PettiColors.marigold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PettiRadii.md),
          borderSide: const BorderSide(color: PettiColors.alert, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PettiRadii.md),
          borderSide: const BorderSide(color: PettiColors.alert, width: 2),
        ),
        errorStyle: PettiText.bodySm().copyWith(color: PettiColors.alert),
      ),

      // Cards — Petti uses custom PettiCard for most surfaces, but Material
      // Card defaults are aligned for consistency.
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PettiRadii.md),
          side: BorderSide(color: PettiColors.borderLight, width: 1),
        ),
      ),

      // Dialogs — Cloud surface, rounded corners.
      dialogTheme: DialogThemeData(
        backgroundColor: PettiColors.cloud,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PettiRadii.lg),
        ),
        titleTextStyle: PettiText.h3(),
        contentTextStyle: PettiText.body(),
      ),

      // SnackBars — Midnight surface, used by error/info toasts.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PettiColors.midnight,
        contentTextStyle: PettiText.body().copyWith(color: PettiColors.cloud),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PettiRadii.md),
        ),
        actionTextColor: PettiColors.marigoldBright,
      ),

      // Switch / Checkbox / Radio — Marigold for the "on" state.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PettiColors.midnight;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PettiColors.marigold;
          return PettiColors.n300;
        }),
      ),

      // Floating action button (rare in Petti UI but consistent if used).
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PettiColors.marigold,
        foregroundColor: PettiColors.midnight,
        elevation: 4,
      ),

      // Loading indicators — Marigold.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PettiColors.marigold,
        linearTrackColor: PettiColors.fog,
        circularTrackColor: PettiColors.fog,
      ),

      // Touchable feedback (used by ListTile, InkWell). Soft marigold ripple.
      splashColor: PettiColors.marigoldSoft,
      highlightColor: PettiColors.marigoldSoft,
    );
  }
}
