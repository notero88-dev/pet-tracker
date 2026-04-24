// Zona Segura setup wizard — 4 steps + error state.
//
// Matches Downloads/Petti - First design App V1/src/zona-wizard.jsx.
//
// Real backend flow:
//   Step 1   purely UX, checklist of readiness
//   Step 2   pick radius (30-300m)
//   Step 3   → POST /devices/:imei/home-zone { radiusMeters }
//              gateway sends DEF,R and awaits DEF_SCAN#MAC,MAC,MAC reply
//              success → step 4; failure → error variant
//   Step 4   show detected WiFi + stats, CTA to dismiss

import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../services/device_commands_api.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/petti/petti_primitives.dart';

class ZonaSeguraWizardScreen extends StatefulWidget {
  final Device device;
  final String petName;
  final DeviceCommandsApi api;

  const ZonaSeguraWizardScreen({
    super.key,
    required this.device,
    required this.petName,
    required this.api,
  });

  @override
  State<ZonaSeguraWizardScreen> createState() => _ZonaSeguraWizardScreenState();
}

class _ZonaSeguraWizardScreenState extends State<ZonaSeguraWizardScreen> {
  int _step = 1; // 1..4
  String? _errorMessage;
  int _radius = 100;
  List<String> _detectedMacs = const [];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 1 || _step == 4 || _errorMessage != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 1) {
          setState(() => _step -= 1);
        }
      },
      child: Scaffold(
        backgroundColor: PettiColors.cloud,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _progressHeader(),
              Expanded(child: _buildStep()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressHeader() {
    final progress = (_step.clamp(1, 4) / 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s2,
        PettiSpacing.s5,
        PettiSpacing.s3,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: _goBack,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'PASO ${_step.clamp(1, 4)} DE 4',
                    style: PettiText.meta().copyWith(letterSpacing: 0.72),
                  ),
                ),
              ),
              _circleIconButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: PettiSpacing.s4),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(PettiRadii.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: PettiColors.n200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(PettiColors.marigold),
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (_step == 1 || _step == 4) {
      Navigator.of(context).pop();
      return;
    }
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
        _step = 2; // back to radius picker from error
      });
      return;
    }
    setState(() => _step -= 1);
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(side: BorderSide(color: PettiColors.borderLight)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: PettiColors.midnight, size: 18),
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_errorMessage != null) {
      return _StepError(
        message: _errorMessage!,
        onBack: () => setState(() {
          _errorMessage = null;
          _step = 2;
        }),
        onRetry: _submitHomeZone,
      );
    }
    switch (_step) {
      case 1:
        return _StepPrepare(
          petName: widget.petName,
          onNext: () => setState(() => _step = 2),
        );
      case 2:
        return _StepRadius(
          radius: _radius,
          onChange: (v) => setState(() => _radius = v),
          onNext: _submitHomeZone,
        );
      case 3:
        return const _StepScanning();
      case 4:
        return _StepSuccess(
          radius: _radius,
          macs: _detectedMacs,
          onDone: () => Navigator.of(context).pop(true),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submitHomeZone() async {
    setState(() => _step = 3);
    final result = await widget.api.setHomeZone(
      imei: widget.device.uniqueId,
      radiusMeters: _radius,
    );
    if (!mounted) return;

    if (result is DeviceCommandOk) {
      // Parse the MAC list from the device's DEF_SCAN reply payload.
      // Format per protocol PDF §3.16:
      //   DEF_SCAN#MAC1,MAC2,MAC3
      // or on failure:
      //   DEF_SCAN#WIFI is invalid, please try again
      final payload = result.reply['payload'] as String? ?? '';
      final macs = _parseMacs(payload);
      if (macs.length < 3) {
        setState(() {
          _errorMessage =
              'No encontramos suficientes redes WiFi. Necesitamos al menos 3 cerca para reconocer tu casa. Acércate un poco a tu router y volvemos a intentar.';
          _step = 2;
        });
        return;
      }
      setState(() {
        _detectedMacs = macs;
        _step = 4;
      });
    } else if (result is DeviceCommandError) {
      setState(() {
        _errorMessage = _friendlyError(result);
        _step = 2;
      });
    }
  }

  List<String> _parseMacs(String payload) {
    final hashIdx = payload.indexOf('#');
    final tail = hashIdx >= 0 ? payload.substring(hashIdx + 1) : payload;
    if (tail.toLowerCase().contains('invalid')) return const [];
    return tail
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.length >= 12 && !s.contains(' '))
        .toList();
  }

  String _friendlyError(DeviceCommandError e) {
    if (e.isOffline) {
      return 'El tracker de ${widget.petName} está desconectado. Asegúrate de que esté encendido.';
    }
    if (e.isTimeout) {
      return 'El tracker no respondió a tiempo. Intenta de nuevo en unos segundos.';
    }
    if (e.isRejectedByDevice) {
      return 'No pudimos configurar la zona. Asegúrate de que el tracker tenga señal GPS (LED verde fijo).';
    }
    return e.message;
  }
}

// =============================================================================
// STEP 1 — Prepare
// =============================================================================

class _StepPrepare extends StatefulWidget {
  final String petName;
  final VoidCallback onNext;
  const _StepPrepare({required this.petName, required this.onNext});

  @override
  State<_StepPrepare> createState() => _StepPrepareState();
}

class _StepPrepareState extends State<_StepPrepare> {
  final _checks = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final items = [
      'Estoy en casa, cerca del tracker de ${widget.petName}',
      'El tracker está encendido (LED azul encendido)',
      'Estoy cerca de una ventana o al aire libre',
    ];
    final allDone = _checks.every((c) => c);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s4,
        PettiSpacing.s5,
        PettiSpacing.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _illustrationHouseWithDog(),
          const SizedBox(height: PettiSpacing.s5),
          Text(
            'Prepara la zona segura de ${widget.petName}',
            style: PettiText.h1(),
          ),
          const SizedBox(height: 10),
          Text(
            'La zona segura ahorra batería. Cuando ${widget.petName} esté en '
            'casa, el tracker duerme. Cuando salga — te avisamos al instante.',
            style: PettiText.lead().copyWith(fontSize: 14),
          ),
          const SizedBox(height: PettiSpacing.s5),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _CheckItem(
                label: items[i],
                checked: _checks[i],
                onTap: () => setState(() => _checks[i] = !_checks[i]),
              ),
            ),
          ),
          const SizedBox(height: PettiSpacing.s4),
          PettiCta(
            label: 'Continuar',
            onPressed: allDone ? widget.onNext : null,
          ),
        ],
      ),
    );
  }

  Widget _illustrationHouseWithDog() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.4, 0.2),
          radius: 0.6,
          colors: [
            PettiColors.marigoldSoft,
            PettiColors.sand,
          ],
          stops: const [0, 1],
        ),
        borderRadius: BorderRadius.circular(PettiRadii.lg - 4),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(220, 150),
        painter: _HouseDogIllustration(),
      ),
    );
  }
}

class _HouseDogIllustration extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final housePaint = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = PettiColors.midnight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    // House body
    final house = Path()
      ..moveTo(60, 75)
      ..lineTo(100, 43)
      ..lineTo(140, 75)
      ..lineTo(140, 125)
      ..lineTo(60, 125)
      ..close();
    canvas.drawPath(house, housePaint);
    canvas.drawPath(house, stroke);

    // Door
    final door = Paint()..color = PettiColors.marigoldSoft;
    canvas.drawRect(const Rect.fromLTWH(90, 106, 20, 22), door);
    canvas.drawRect(const Rect.fromLTWH(90, 106, 20, 22), stroke);

    // WiFi arcs
    final wifi = Paint()
      ..color = PettiColors.marigold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final arc1 = Path()
      ..moveTo(140, 70)
      ..quadraticBezierTo(154, 60, 168, 70);
    canvas.drawPath(arc1, wifi);
    final arc2 = Path()
      ..moveTo(144, 78)
      ..quadraticBezierTo(154, 72, 164, 78);
    canvas.drawPath(arc2..close(), wifi..color = PettiColors.marigold.withValues(alpha: 0.7));
    canvas.drawCircle(
      const Offset(154, 86),
      2,
      Paint()..color = PettiColors.marigold,
    );

    // Dog (on the right)
    final dogBody = Paint()..color = PettiColors.cafe;
    canvas.drawCircle(const Offset(188, 120), 6, dogBody);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(196, 128), width: 20, height: 10),
      dogBody,
    );
    canvas.drawCircle(
      const Offset(186, 119),
      1.5,
      Paint()..color = Colors.white,
    );

    // Person silhouette (near dog)
    final personStroke = Paint()
      ..color = PettiColors.midnight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(const Offset(170, 100), 7, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(170, 100), 7, personStroke);
    final body = Path()
      ..moveTo(162, 130)
      ..quadraticBezierTo(170, 110, 178, 130);
    canvas.drawPath(body, personStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _CheckItem({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? PettiColors.sabanaSoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: checked
                  ? PettiColors.sabana.withValues(alpha: 0.3)
                  : PettiColors.borderLight,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: checked ? PettiColors.sabana : Colors.white,
                  border: Border.all(
                    color:
                        checked ? PettiColors.sabana : PettiColors.n300,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: PettiText.body().copyWith(
                    fontWeight: FontWeight.w500,
                    color: PettiColors.midnight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STEP 2 — Radius
// =============================================================================

class _StepRadius extends StatelessWidget {
  final int radius;
  final ValueChanged<int> onChange;
  final VoidCallback onNext;

  const _StepRadius({
    required this.radius,
    required this.onChange,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s4,
        PettiSpacing.s5,
        PettiSpacing.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Qué tan grande es tu zona?', style: PettiText.h1()),
          const SizedBox(height: 10),
          Text(
            'Define el radio alrededor de tu casa donde el tracker puede '
            'dormir tranquilo.',
            style: PettiText.lead().copyWith(fontSize: 14),
          ),
          const SizedBox(height: PettiSpacing.s5),
          // Symbolic house with growing circle
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: PettiColors.sand,
                borderRadius: BorderRadius.circular(PettiRadii.lg - 4),
              ),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(280, 200),
                painter: _RadiusSymbolic(radius),
              ),
            ),
          ),
          const SizedBox(height: PettiSpacing.s4),
          // Value + slider
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RADIO',
                  style:
                      PettiText.meta().copyWith(letterSpacing: 0.72)),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$radius',
                      style: PettiText.number(
                        size: 28,
                        weight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' m',
                      style: PettiText.number(
                        size: 16,
                        weight: FontWeight.w600,
                      ).copyWith(color: PettiColors.trail),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: PettiColors.marigold,
              inactiveTrackColor: PettiColors.n200,
              thumbColor: PettiColors.marigold,
              overlayColor: PettiColors.marigoldSoft,
              trackHeight: 6,
            ),
            child: Slider(
              value: radius.toDouble(),
              min: 30,
              max: 300,
              divisions: 27,
              onChanged: (v) => onChange(v.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('30 M',
                    style: PettiText.meta().copyWith(fontSize: 11)),
                Text('300 M',
                    style: PettiText.meta().copyWith(fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: PettiSpacing.s4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: PettiColors.marigoldSoft,
              borderRadius: BorderRadius.circular(PettiRadii.sm),
            ),
            child: Text(
              '100 metros funciona bien para casas con patio o apartamentos con portería.',
              style: PettiText.bodySm().copyWith(fontSize: 12.5),
            ),
          ),
          const SizedBox(height: PettiSpacing.s4),
          PettiCta(label: 'Configurar zona', onPressed: onNext),
        ],
      ),
    );
  }
}

class _RadiusSymbolic extends CustomPainter {
  final int radius;
  _RadiusSymbolic(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = 0.2 + (radius / 300) * 0.65;
    final r = 70.0 * scale + 20;
    final center = Offset(size.width / 2, size.height / 2);

    // Dashed green circle
    final fill = Paint()..color = PettiColors.sabanaSoft;
    canvas.drawCircle(center, r, fill);

    final stroke = Paint()
      ..color = PettiColors.sabana
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const segments = 24;
    for (int i = 0; i < segments; i++) {
      if (i % 2 == 0) continue;
      final start = (i / segments) * 2 * 3.14159;
      final end = ((i + 1) / segments) * 2 * 3.14159;
      final path = Path()
        ..addArc(Rect.fromCircle(center: center, radius: r), start,
            end - start);
      canvas.drawPath(path, stroke);
    }

    // House
    final housePaint = Paint()..color = Colors.white;
    final houseStroke = Paint()
      ..color = PettiColors.midnight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(center.dx - 25, center.dy - 12)
      ..lineTo(center.dx, center.dy - 32)
      ..lineTo(center.dx + 25, center.dy - 12)
      ..lineTo(center.dx + 25, center.dy + 24)
      ..lineTo(center.dx - 25, center.dy + 24)
      ..close();
    canvas.drawPath(path, housePaint);
    canvas.drawPath(path, houseStroke);

    // Door
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 8, center.dy + 10, 16, 14),
      houseStroke,
    );

    // Radius label above circle
    final tp = TextPainter(
      text: TextSpan(
        text: '$radius m',
        style: PettiText.number(size: 12, weight: FontWeight.w600)
            .copyWith(color: PettiColors.sabana),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - r - 20),
    );
  }

  @override
  bool shouldRepaint(covariant _RadiusSymbolic old) => old.radius != radius;
}

// =============================================================================
// STEP 3 — Scanning (pulse visual)
// =============================================================================

class _StepScanning extends StatefulWidget {
  const _StepScanning();

  @override
  State<_StepScanning> createState() => _StepScanningState();
}

class _StepScanningState extends State<_StepScanning>
    with TickerProviderStateMixin {
  int _phase = 0;
  late final _phaseTimer = Stream.periodic(
    const Duration(milliseconds: 2400),
    (i) => i % 3,
  ).listen((p) {
    if (mounted) setState(() => _phase = p);
  });

  final _phases = const [
    ('Buscando redes WiFi cercanas…', 'Esto ayuda al tracker a reconocer tu casa.'),
    ('Obteniendo ubicación GPS…', 'Anclamos el centro de la zona.'),
    ('Casi listo…', 'Aplicando ajustes al tracker.'),
  ];

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _phaseTimer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s4,
        PettiSpacing.s5,
        PettiSpacing.s7,
      ),
      child: Column(
        children: [
          const Spacer(),
          // Pulse illustration
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.1),
                radius: 0.7,
                colors: [
                  PettiColors.marigold.withValues(alpha: 0.22),
                  PettiColors.sand,
                ],
                stops: const [0, 1],
              ),
              borderRadius: BorderRadius.circular(PettiRadii.lg),
            ),
            alignment: Alignment.center,
            child: _PulseHome(controller: _pulseCtrl),
          ),
          const SizedBox(height: PettiSpacing.s5 + 4),
          Text(
            _phases[_phase].$1,
            style: PettiText.h2().copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PettiSpacing.s2),
          Text(
            _phases[_phase].$2,
            style: PettiText.body(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PettiSpacing.s5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _phase
                        ? PettiColors.marigold
                        : PettiColors.n200,
                    borderRadius: BorderRadius.circular(PettiRadii.pill),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _PulseHome extends StatelessWidget {
  final AnimationController controller;
  const _PulseHome({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final delayStep in [0.0, 0.33, 0.66])
                _PulseRing(
                  progress: ((controller.value + (1 - delayStep)) % 1),
                ),
              // Home icon in a white tile
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: PettiColors.marigold.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.home_rounded,
                  color: PettiColors.marigoldDim,
                  size: 22,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final double progress; // 0..1
  const _PulseRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final scale = 0.5 + progress * 2.7;
    final opacity = (1 - progress).clamp(0.0, 0.9);
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: PettiColors.marigold, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STEP 4 — Success
// =============================================================================

class _StepSuccess extends StatelessWidget {
  final int radius;
  final List<String> macs;
  final VoidCallback onDone;

  const _StepSuccess({
    required this.radius,
    required this.macs,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s4,
        PettiSpacing.s5,
        PettiSpacing.s5,
      ),
      child: ListView(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.2),
                radius: 0.6,
                colors: [
                  PettiColors.sabana.withValues(alpha: 0.18),
                  PettiColors.sand,
                ],
                stops: const [0, 1],
              ),
              borderRadius: BorderRadius.circular(PettiRadii.lg),
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(200, 160),
              painter: _HappyHouseDog(),
            ),
          ),
          const SizedBox(height: PettiSpacing.s4 + 6),
          Text(
            '¡Listo! Zona segura activa 🐾',
            style: PettiText.h1().copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu mascota puede entrar y salir tranquila. Te avisaremos cada '
            'vez que cruce la zona.',
            style: PettiText.lead().copyWith(fontSize: 14),
          ),
          const SizedBox(height: PettiSpacing.s5),
          // Detected WiFi networks card
          Container(
            padding: const EdgeInsets.all(PettiSpacing.s4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(PettiRadii.md),
              border: Border.all(color: PettiColors.borderLight, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REDES WIFI DETECTADAS',
                  style: PettiText.meta().copyWith(letterSpacing: 0.96),
                ),
                const SizedBox(height: 10),
                for (final (i, mac) in macs.indexed) ...[
                  if (i > 0)
                    Container(height: 1, color: PettiColors.borderLight),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_rounded,
                          size: 16,
                          color: PettiColors.sabana,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _maskedMac(mac),
                            style: PettiText.body().copyWith(
                              fontSize: 13.5,
                              color: PettiColors.midnight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PettiSpacing.s3 + 2),
          Row(
            children: [
              PettiInfoStat(label: 'Radio', value: '$radius m'),
              const SizedBox(width: 10),
              const PettiInfoStat(
                label: 'Antes',
                value: '~3 d',
                muted: true,
              ),
              const SizedBox(width: 10),
              const PettiInfoStat(
                label: 'Ahora',
                value: '~14 d',
                accent: true,
              ),
            ],
          ),
          const SizedBox(height: PettiSpacing.s4),
          PettiCta(label: 'Entendido', onPressed: onDone),
        ],
      ),
    );
  }

  /// Mask a raw MAC address for display: first/last 2 chars, dots between.
  String _maskedMac(String mac) {
    if (mac.length < 4) return 'Red detectada · ••••';
    return '${mac.substring(0, 2)}••••${mac.substring(mac.length - 2)} · ••••';
  }
}

class _HappyHouseDog extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = PettiColors.midnight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    // House
    final house = Path()
      ..moveTo(60, 82)
      ..lineTo(100, 50)
      ..lineTo(140, 82)
      ..lineTo(140, 133)
      ..lineTo(60, 133)
      ..close();
    canvas.drawPath(house, Paint()..color = Colors.white);
    canvas.drawPath(house, stroke);

    // Door with marigold-soft fill
    final door = Paint()..color = PettiColors.marigoldSoft;
    canvas.drawRect(const Rect.fromLTWH(88, 115, 24, 18), door);
    canvas.drawRect(const Rect.fromLTWH(88, 115, 24, 18), stroke);

    // Dog inside
    final dogBody = Paint()..color = PettiColors.cafe;
    canvas.drawCircle(const Offset(150, 108), 12, dogBody);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(155, 122), width: 28, height: 16),
      dogBody,
    );
    canvas.drawCircle(
      const Offset(147, 106),
      1.5,
      Paint()..color = Colors.white,
    );

    // Check badge
    canvas.drawCircle(
      const Offset(160, 62),
      18,
      Paint()..color = PettiColors.sabana,
    );
    final checkStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final check = Path()
      ..moveTo(152, 62)
      ..lineTo(158, 68)
      ..lineTo(168, 58);
    canvas.drawPath(check, checkStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// Error variant
// =============================================================================

class _StepError extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  const _StepError({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PettiSpacing.s5,
        PettiSpacing.s4,
        PettiSpacing.s5,
        PettiSpacing.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.2),
                radius: 0.6,
                colors: [
                  PettiColors.duskSoft,
                  PettiColors.sand,
                ],
                stops: const [0, 1],
              ),
              borderRadius: BorderRadius.circular(PettiRadii.lg),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 84,
              color: PettiColors.duskRose,
            ),
          ),
          const SizedBox(height: PettiSpacing.s5),
          Text(
            'Algo no salió bien',
            style: PettiText.h1().copyWith(fontSize: 24),
          ),
          const SizedBox(height: 10),
          Text(message, style: PettiText.lead().copyWith(fontSize: 14)),
          const SizedBox(height: PettiSpacing.s5),
          Container(
            padding: const EdgeInsets.all(PettiSpacing.s4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(PettiRadii.md),
              border: Border.all(color: PettiColors.borderLight, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUGERENCIAS',
                  style: PettiText.meta().copyWith(letterSpacing: 0.72),
                ),
                const SizedBox(height: 10),
                for (final s in const [
                  'Acércate al router principal',
                  'Asegúrate de que el tracker esté cerca',
                  'Espera unos segundos — a veces tarda',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 6,
                          color: PettiColors.duskRose,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s,
                            style: PettiText.body().copyWith(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: PettiCta(
                  label: 'Atrás',
                  variant: PettiCtaVariant.secondary,
                  onPressed: onBack,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PettiCta(
                  label: 'Reintentar',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: onRetry,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
