// Petti onboarding — abstract device illustration.
//
// A stylized rendering of the Petti collar puck used on pairing screens
// (A4.1 "Saca tu Petti", and as a hero motif inside other illustrations).
// Not a literal photo of the hardware — a tactile, soft-shadowed shape
// with the Petti paw mark inside, in Marigold.
//
// Source: design package screens-shared.jsx (PettiPuck).
// 2026-04-29 design delivery.

import 'package:flutter/material.dart';

import '../../utils/petti_theme.dart';

class PettiPuck extends StatelessWidget {
  /// Total visual width. Height is computed (height ≈ 0.62 × size).
  final double size;

  /// Show the warm radial glow behind the puck. On in most contexts;
  /// off when the puck sits inside another already-glowing element.
  final bool glow;

  const PettiPuck({super.key, this.size = 220, this.glow = true});

  @override
  Widget build(BuildContext context) {
    final h = size * 0.62;
    return SizedBox(
      width: size,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glow)
            Container(
              width: size * 1.6,
              height: h * 1.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE8A33D).withValues(alpha: 0.22),
                    const Color(0xFFE8A33D).withValues(alpha: 0),
                  ],
                  stops: const [0, 0.65],
                ),
              ),
            ),
          // Puck body — rounded soft pill with deep gradient.
          Container(
            width: size * 0.7,
            height: size * 0.7 / 1.2,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.all(Radius.elliptical(size * 0.28, size * 0.35)),
              gradient: const LinearGradient(
                begin: Alignment(-0.6, -0.8),
                end: Alignment(0.6, 0.8),
                colors: [
                  Color(0xFF2A3645),
                  Color(0xFF182A42),
                  Color(0xFF0E1B2C),
                ],
                stops: [0, 0.6, 1],
              ),
              border: Border.all(
                color: const Color(0xFFFAF7F2).withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: size * 0.27,
                height: size * 0.27,
                child: const _PawMark(color: PettiColors.marigold),
              ),
            ),
          ),
          // D-ring loop on the upper-right edge of the puck.
          Positioned(
            top: h * 0.12,
            right: size * 0.13,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFAF7F2).withValues(alpha: 0.18),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petti's paw glyph — 4 toe pads above a soft pad. Centered in a
/// 24×24 logical box; scales to fit any container.
class _PawMark extends StatelessWidget {
  final Color color;
  const _PawMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PawPainter(color: color),
    );
  }
}

class _PawPainter extends CustomPainter {
  final Color color;
  _PawPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Scale from a 24x24 logical canvas.
    final s = size.width / 24;
    // Toe pads.
    canvas.drawCircle(Offset(6 * s, 7 * s), 1.6 * s, paint);
    canvas.drawCircle(Offset(10.5 * s, 5 * s), 1.6 * s, paint);
    canvas.drawCircle(Offset(13.5 * s, 5 * s), 1.6 * s, paint);
    canvas.drawCircle(Offset(18 * s, 7 * s), 1.6 * s, paint);
    // Main pad — rounded blob below.
    final padPath = Path()
      ..moveTo(12 * s, 9.5 * s)
      ..cubicTo(9 * s, 9.5 * s, 7 * s, 12 * s, 7 * s, 14 * s)
      ..cubicTo(7 * s, 15.8 * s, 8.4 * s, 16.8 * s, 10 * s, 16.8 * s)
      ..lineTo(14 * s, 16.8 * s)
      ..cubicTo(15.6 * s, 16.8 * s, 17 * s, 15.8 * s, 17 * s, 14 * s)
      ..cubicTo(17 * s, 12 * s, 15 * s, 9.5 * s, 12 * s, 9.5 * s)
      ..close();
    canvas.drawPath(padPath, paint);
  }

  @override
  bool shouldRepaint(_PawPainter old) => old.color != color;
}
