// Zona Segura section — two states: empty (prompt to configure) and
// configured (mini map preview + radius/WiFi/date stats + Update button).

import 'package:flutter/material.dart';
import '../../utils/petti_theme.dart';
import 'petti_primitives.dart';

// -----------------------------------------------------------------------------
// Empty state — when no Home Zone is configured yet.
// -----------------------------------------------------------------------------

class PettiZonaSeguraEmpty extends StatelessWidget {
  final VoidCallback onConfigure;
  const PettiZonaSeguraEmpty({super.key, required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PettiSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration — symbolic house with dashed circle.
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.4),
                radius: 0.7,
                colors: [PettiColors.sabanaSoft, PettiColors.sand],
                stops: const [0, 1],
              ),
              borderRadius: BorderRadius.circular(PettiRadii.md - 2),
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(90, 80),
              painter: _HousePainter(),
            ),
          ),
          const SizedBox(height: PettiSpacing.s3 + 2),
          Text(
            'Configura la zona segura',
            style: PettiText.h4(),
          ),
          const SizedBox(height: 6),
          Text(
            'Tu dispositivo entra en modo bajo consumo cuando detecta el WiFi '
            'de tu casa — y vuelve a rastrear cuando Canela sale.',
            style: PettiText.bodySm(),
          ),
          const SizedBox(height: PettiSpacing.s3 + 2),
          PettiCta(
            label: 'Configurar zona segura',
            onPressed: onConfigure,
            icon: const Icon(Icons.home_rounded),
          ),
        ],
      ),
    );
  }
}

class _HousePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final circleStroke = Paint()
      ..color = PettiColors.sabana.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Dashed circle manually (Flutter doesn't have native dash).
    final center = Offset(size.width / 2, size.height / 2);
    _dashedCircle(canvas, center, 32, circleStroke, 4, 4);

    final housePaint = Paint()..color = Colors.white;
    final houseStroke = Paint()
      ..color = PettiColors.midnight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    // House body
    final path = Path()
      ..moveTo(size.width / 2 - 15, size.height / 2 - 3)
      ..lineTo(size.width / 2, size.height / 2 - 16)
      ..lineTo(size.width / 2 + 15, size.height / 2 - 3)
      ..lineTo(size.width / 2 + 15, size.height / 2 + 15)
      ..lineTo(size.width / 2 - 15, size.height / 2 + 15)
      ..close();
    canvas.drawPath(path, housePaint);
    canvas.drawPath(path, houseStroke);

    // Door
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 - 5,
        size.height / 2 + 7,
        10,
        8,
      ),
      houseStroke,
    );
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint,
      double dash, double gap) {
    const steps = 360 / 16; // 16 dashes
    for (int i = 0; i < 16; i++) {
      final start = (i * steps) * 3.14159 / 180;
      final end = start + (dash / (2 * 3.14159 * radius)) * 2 * 3.14159;
      final path = Path()
        ..addArc(Rect.fromCircle(center: center, radius: radius), start,
            end - start);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// Configured state — mini map preview + stats.
// -----------------------------------------------------------------------------

class PettiZonaSeguraConfigured extends StatelessWidget {
  final String radiusLabel;
  final int networkCount;
  final String configuredOn;
  final VoidCallback onUpdate;

  const PettiZonaSeguraConfigured({
    super.key,
    required this.radiusLabel,
    required this.networkCount,
    required this.configuredOn,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini map
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PettiRadii.md),
          ),
          child: SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _MiniMapPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(PettiSpacing.s4 + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PettiStatusPill(
                          kind: PettiStatus.online,
                          label: 'Activa',
                        ),
                        const SizedBox(height: PettiSpacing.s2),
                        Text(
                          'Casa · Chapinero',
                          style: PettiText.h4(),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onUpdate,
                    borderRadius: BorderRadius.circular(PettiRadii.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PettiSpacing.s3 + 2,
                        vertical: PettiSpacing.s2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(PettiRadii.sm),
                        border: Border.all(
                          color: PettiColors.borderLightStrong,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Actualizar',
                        style: PettiText.bodyStrong().copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PettiSpacing.s3 + 2),
              Row(
                children: [
                  PettiInfoStat(label: 'Radio', value: radiusLabel),
                  const SizedBox(width: PettiSpacing.s3),
                  PettiInfoStat(
                    label: 'WiFi',
                    value: '$networkCount redes',
                  ),
                  const SizedBox(width: PettiSpacing.s3),
                  PettiInfoStat(label: 'Configurado', value: configuredOn),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark grid background
    final bg = Paint()..color = const Color(0xFF13243A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Grid lines
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // A squiggle "road"
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final roadPath = Path()
      ..moveTo(0, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.5,
          size.width * 0.44, size.height * 0.67)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.82,
          size.width, size.height * 0.58);
    canvas.drawPath(roadPath, road);

    // Geofence circle
    final center = Offset(size.width / 2, size.height * 0.5);
    final geofenceFill = Paint()
      ..color = PettiColors.sabana.withValues(alpha: 0.18);
    canvas.drawCircle(center, 48, geofenceFill);

    final geofenceStroke = Paint()
      ..color = PettiColors.sabana
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _drawDashedCircle(canvas, center, 48, geofenceStroke);

    // Center dot
    canvas.drawCircle(center, 5, Paint()..color = PettiColors.sabana);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double r, Paint paint) {
    const segments = 20;
    for (int i = 0; i < segments; i++) {
      if (i % 2 == 0) continue;
      final start = (i / segments) * 2 * 3.14159;
      final end = ((i + 1) / segments) * 2 * 3.14159;
      final path = Path()
        ..addArc(Rect.fromCircle(center: center, radius: r), start,
            end - start);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
