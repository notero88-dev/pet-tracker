// Petti onboarding — pulse rings.
//
// 3 layered rings expanding-and-fading from a central core. The brand's
// signature motion: tech (signal) and warmth (heartbeat) at once. Used
// by A4.4 (paired success, Sabana), A5.1 (despertando, Marigold), and
// A5.3 (taking longer, Dusk Rose) — pass `accent` to switch palette.
//
// Source: design package screens-a4.jsx / screens-a5.jsx + tokens.css
// (--ease, --dur-large). 2026-04-29 design delivery.

import 'package:flutter/material.dart';

import '../../utils/petti_theme.dart';

class PettiPulseRings extends StatefulWidget {
  /// Inner core circle diameter.
  final double coreSize;

  /// Step between successive rings (each is `coreSize + i * step`).
  final double step;

  /// Number of expanding rings.
  final int rings;

  /// Color of every ring + the core.
  final Color accent;

  /// Optional child placed centered inside the core circle (e.g. a
  /// checkmark for "paired" or a home glyph for "configuring").
  final Widget? child;

  /// Make the rings static (no animation). Used in tests / where motion
  /// would be distracting.
  final bool animate;

  const PettiPulseRings({
    super.key,
    this.coreSize = 28,
    this.step = 60,
    this.rings = 3,
    this.accent = PettiColors.marigold,
    this.child,
    this.animate = true,
  });

  @override
  State<PettiPulseRings> createState() => _PettiPulseRingsState();
}

class _PettiPulseRingsState extends State<PettiPulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxSize = widget.coreSize + widget.step * widget.rings;
    return SizedBox(
      width: maxSize,
      height: maxSize,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 1; i <= widget.rings; i++) _ring(i),
              _core(),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(int i) {
    // Each ring is offset in time by 1/rings of the cycle so they
    // expand in a staggered chase.
    final phase = ((_ctrl.value + i / widget.rings) % 1.0);
    final size = widget.coreSize + widget.step * i * phase;
    final opacity = (1.0 - phase) * (0.5 - i * 0.08);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.accent.withValues(alpha: opacity.clamp(0, 1)),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _core() {
    return Container(
      width: widget.coreSize,
      height: widget.coreSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.accent,
        boxShadow: [
          BoxShadow(
            color: widget.accent.withValues(alpha: 0.7),
            blurRadius: 30,
          ),
        ],
      ),
      child: widget.child == null
          ? null
          : Center(child: widget.child!),
    );
  }
}
