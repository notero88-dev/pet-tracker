// Settings entry card for the Zona de casa flow.
//
// Two visual variants per the design bundle
// (`zona-casa-wizard.jsx::ZonaCasaEntryCard`):
//
//   - Unconfigured: hero illustration strip + headline + CTA. Shown
//     when no successful home-setup intent exists for this device.
//   - Configured: compact summary with SSID + battery estimate + a
//     small pulsing dot. The Editar button re-opens the wizard.
//
// Lives under Configuracion > Dispositivo. Replaces the temporary
// ListTile the Phase B Settings entry used.

import 'package:flutter/material.dart';

import '../../utils/petti_theme.dart';
import 'zona_casa_illustrations.dart';

class ZonaCasaEntryCard extends StatelessWidget {
  /// When true, render the compact "configured" variant. When false,
  /// render the hero "unconfigured" variant.
  final bool configured;

  /// Current home SSID — only used by the configured variant.
  final String? ssid;

  /// Battery estimate label (e.g. "~14 días"). Configured variant only.
  final String batteryEstimate;

  /// Tap target — for unconfigured, opens the wizard. For configured,
  /// opens the wizard pre-populated as "edit".
  final VoidCallback onTap;

  const ZonaCasaEntryCard({
    super.key,
    required this.onTap,
    this.configured = false,
    this.ssid,
    this.batteryEstimate = '~14 días',
  });

  @override
  Widget build(BuildContext context) {
    return configured ? _Configured(this) : _Unconfigured(this);
  }
}

class _Unconfigured extends StatelessWidget {
  const _Unconfigured(this.card);
  final ZonaCasaEntryCard card;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: card.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: PettiColors.midnight.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: PettiColors.midnight.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: PettiColors.midnight.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ZonaCasaEntryHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activa el modo Zona de casa',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: PettiColors.midnight,
                        letterSpacing: -0.255, // -0.015em on 17px
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text.rich(
                      const TextSpan(
                        text: 'El tracker se duerme cuando reconoce tu Wi-Fi. '
                            'Hasta ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          color: PettiColors.fg,
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(
                            text: '14 días de batería',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: PettiColors.midnight,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PrimaryCta(
                      onPressed: card.onTap,
                      icon: Icons.home_outlined,
                      label: 'Activar Zona de casa',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Configured extends StatelessWidget {
  const _Configured(this.card);
  final ZonaCasaEntryCard card;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: card.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: PettiColors.midnight.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: PettiColors.midnight.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: PettiColors.midnight.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PettiColors.sabana.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.home_outlined,
                  color: PettiColors.sabana,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Zona de casa',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: PettiColors.midnight,
                              letterSpacing: -0.155,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _PulseDot(color: PettiColors.sabana),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (card.ssid != null) card.ssid!,
                        card.batteryEstimate,
                      ].join(' · '),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: PettiColors.trail,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EditButton(onTap: card.onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _PrimaryCta({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: PettiColors.midnight),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: PettiColors.midnight,
            letterSpacing: -0.075,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: PettiColors.marigold,
          foregroundColor: PettiColors.midnight,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: PettiColors.midnight.withValues(alpha: 0.14),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Editar',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: PettiColors.midnight,
          ),
        ),
      ),
    );
  }
}

/// Tiny pulsing dot indicator. Used in the configured entry card and in
/// the wizard's "Conectado" pill.
class _PulseDot extends StatefulWidget {
  final Color color;
  static const double size = 6;

  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        // Mirror the design's `petti-dot-pulse` keyframes: at 50% the
        // glow spreads to ~5px wide with full transparency at the edge,
        // at 0/100 it's tight.
        final phase = (1 - (_ctl.value - 0.5).abs() * 2).clamp(0.0, 1.0);
        final glow = 5.0 * phase;
        final glowOpacity = 0.6 * (1 - phase);
        return Container(
          width: _PulseDot.size,
          height: _PulseDot.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glowOpacity),
                blurRadius: 0,
                spreadRadius: glow,
              ),
            ],
          ),
        );
      },
    );
  }
}
