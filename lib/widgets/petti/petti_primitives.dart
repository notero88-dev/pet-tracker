// Petti reusable primitives — Card, SectionHeader, Cta, StatusPill, ListRow, etc.
//
// These map one-to-one with the components in the React prototype
// (src/settings-primitives.jsx + petti-components.jsx). Keeping them in one
// file so they're easy to find and to tweak.

import 'package:flutter/material.dart';
import '../../utils/petti_theme.dart';

// -----------------------------------------------------------------------------
// Card — white surface with warm shadow.
// -----------------------------------------------------------------------------

class PettiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Border? border;
  final double radius;
  final bool shadow;

  const PettiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PettiSpacing.s4),
    this.margin = const EdgeInsets.symmetric(horizontal: PettiSpacing.s4),
    this.color,
    this.border,
    this.radius = PettiRadii.md,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadow ? PettiShadows.elevation1 : null,
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// SectionHeader — "MODO DE RASTREO" style eyebrow above each card.
// -----------------------------------------------------------------------------

class PettiSectionHeader extends StatelessWidget {
  final String label;
  final Color? color;
  const PettiSectionHeader(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s4,
        PettiSpacing.s5,
        PettiSpacing.s2,
      ),
      child: Text(
        label.toUpperCase(),
        style: PettiText.meta().copyWith(color: color ?? PettiColors.trail),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Cta — primary/secondary/danger buttons. Full width, 16pt radius, pill option.
// -----------------------------------------------------------------------------

enum PettiCtaVariant { primary, secondary, danger }

class PettiCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PettiCtaVariant variant;
  final Widget? icon;
  final bool loading;

  const PettiCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PettiCtaVariant.primary,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    Color bg, fg, border;
    switch (variant) {
      case PettiCtaVariant.primary:
        bg = disabled
            ? PettiColors.marigold.withValues(alpha: 0.42)
            : PettiColors.marigold;
        fg = Colors.white;
        border = Colors.transparent;
        break;
      case PettiCtaVariant.secondary:
        bg = Colors.white;
        fg = PettiColors.midnight;
        border = PettiColors.borderLightStrong;
        break;
      case PettiCtaVariant.danger:
        bg = PettiColors.alert;
        fg = Colors.white;
        border = Colors.transparent;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(PettiRadii.md),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PettiRadii.md),
              border: Border.all(color: border, width: 1),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                else if (icon != null)
                  IconTheme(
                    data: IconThemeData(color: fg, size: 18),
                    child: icon!,
                  ),
                if ((icon != null || loading) && label.isNotEmpty)
                  const SizedBox(width: PettiSpacing.s2),
                Text(
                  label,
                  style: PettiText.bodyStrong().copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// StatusPill — "En línea", "Desconectada hace 12 min", etc.
// -----------------------------------------------------------------------------

enum PettiStatus { online, offline, warning }

class PettiStatusPill extends StatelessWidget {
  final PettiStatus kind;
  final String label;

  const PettiStatusPill({super.key, required this.kind, required this.label});

  @override
  Widget build(BuildContext context) {
    Color bg, dotColor, textColor;
    switch (kind) {
      case PettiStatus.online:
        bg = PettiColors.sabanaSoft;
        dotColor = PettiColors.sabana;
        textColor = PettiColors.sabana;
        break;
      case PettiStatus.offline:
        bg = PettiColors.duskSoft;
        dotColor = PettiColors.duskRose;
        textColor = PettiColors.duskRose;
        break;
      case PettiStatus.warning:
        bg = PettiColors.marigoldSoft;
        dotColor = PettiColors.marigoldDim;
        textColor = PettiColors.marigoldDim;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PettiSpacing.s3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PettiRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: PettiText.bodySm().copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// BatteryBadge — icon + %.
// -----------------------------------------------------------------------------

class PettiBatteryBadge extends StatelessWidget {
  final int percentBucket; // 20, 40, 60, 80, 100
  const PettiBatteryBadge({super.key, required this.percentBucket});

  @override
  Widget build(BuildContext context) {
    final isLow = percentBucket <= 20;
    final color = isLow ? PettiColors.alert : PettiColors.midnight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stylized battery icon (outline + fill proportional to %).
        CustomPaint(
          size: const Size(22, 12),
          painter: _BatteryIconPainter(
            percent: percentBucket / 100,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$percentBucket%',
          style: PettiText.number(size: 14, weight: FontWeight.w700)
              .copyWith(color: color),
        ),
      ],
    );
  }
}

class _BatteryIconPainter extends CustomPainter {
  final double percent;
  final Color color;

  _BatteryIconPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bodyWidth = size.width - 2;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bodyWidth, size.height),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(body, stroke);

    // Nub
    canvas.drawRect(
      Rect.fromLTWH(bodyWidth, 3, 2, size.height - 6),
      fill,
    );

    // Fill
    const padding = 1.5;
    final fillWidth = (bodyWidth - padding * 2) * percent.clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, padding, fillWidth, size.height - padding * 2),
        const Radius.circular(1),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryIconPainter old) =>
      old.percent != percent || old.color != color;
}

// -----------------------------------------------------------------------------
// ListRow — label + value row for device info cards.
// -----------------------------------------------------------------------------

class PettiListRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? right;
  final bool mono;
  final bool danger;
  final bool last;
  final VoidCallback? onTap;

  const PettiListRow({
    super.key,
    required this.label,
    this.value,
    this.right,
    this.mono = false,
    this.danger = false,
    this.last = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = danger
        ? PettiText.body().copyWith(
            color: PettiColors.alert,
            fontWeight: FontWeight.w600,
          )
        : PettiText.body().copyWith(
            color: PettiColors.midnight,
            fontWeight: FontWeight.w500,
          );

    final valueStyle = mono
        ? PettiText.number(size: 13, weight: FontWeight.w500).copyWith(
            color: PettiColors.fg,
          )
        : PettiText.body().copyWith(color: PettiColors.fg);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: PettiSpacing.s3),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(color: PettiColors.borderLight, width: 1),
                ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: labelStyle)),
            if (value != null)
              Text(value!, style: valueStyle, overflow: TextOverflow.ellipsis),
            if (right != null) ...[
              const SizedBox(width: PettiSpacing.s2),
              right!,
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RecommendedBadge — green "Recomendado" pill.
// -----------------------------------------------------------------------------

class PettiRecommendedBadge extends StatelessWidget {
  const PettiRecommendedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: PettiColors.sabanaSoft,
        borderRadius: BorderRadius.circular(PettiRadii.pill),
      ),
      child: Text(
        'RECOMENDADO',
        style: PettiText.meta().copyWith(
          color: PettiColors.sabana,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// InfoStat — label + value in a column, used inside the configured Zona
// Segura card and the Success step.
// -----------------------------------------------------------------------------

class PettiInfoStat extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  final bool muted;

  const PettiInfoStat({
    super.key,
    required this.label,
    required this.value,
    this.accent = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = accent
        ? PettiColors.sabanaSoft
        : muted
            ? PettiColors.sand
            : Colors.white;
    final borderColor = accent
        ? PettiColors.sabana.withValues(alpha: 0.25)
        : PettiColors.borderLight;
    final valueColor = accent
        ? PettiColors.sabana
        : muted
            ? PettiColors.trail
            : PettiColors.midnight;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PettiSpacing.s3,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: PettiText.meta().copyWith(
                fontSize: 10,
                letterSpacing: 0.72,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: PettiText.number(size: 16, weight: FontWeight.w700)
                  .copyWith(
                color: valueColor,
                decoration: muted ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PetAvatar — initial letter in marigold gradient box.
// -----------------------------------------------------------------------------

class PettiPetAvatar extends StatelessWidget {
  final String initial;
  final double size;
  const PettiPetAvatar({super.key, required this.initial, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4D9A8), PettiColors.marigold],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1B2C).withValues(alpha: 0.08),
            offset: const Offset(0, -2),
            blurRadius: 6,
            spreadRadius: -4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: PettiText.h2().copyWith(
          fontSize: size * 0.4,
          color: PettiColors.midnight,
        ),
      ),
    );
  }
}
