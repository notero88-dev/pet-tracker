// First-position waiting screen — Petti restyle.
//
// After the user provisions their device, this screen polls Traccar
// every 5s waiting for the MT710's first GPS fix to come through.
//
// Three states:
//   waiting  — pulsing satellite icon over Marigold-soft, instructions,
//              live waiting timer, blue "tip" replaced with Sabana-soft
//              calm note, soft "Omitir por ahora" escape hatch
//   success  — full-bleed Marigold gradient with Cloud check medallion,
//              quick stat card, auto-routes to SetupGeofence after 2s
//   timeout  — "Sin señal" hero with Marigold-soft warning panel listing
//              troubleshooting bullets, retry + skip-for-now CTAs
//
// All three reuse the existing Petti tokens. The success state's
// gradient is intentionally different from the brand-flat Marigold of
// other Petti surfaces: success is a moment, the celebration is OK.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import '../../utils/petti_theme.dart';
import 'setup_geofence_screen.dart';

class FirstPositionScreen extends StatefulWidget {
  final Device device;
  final String petName;

  const FirstPositionScreen({
    super.key,
    required this.device,
    required this.petName,
  });

  @override
  State<FirstPositionScreen> createState() => _FirstPositionScreenState();
}

class _FirstPositionScreenState extends State<FirstPositionScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  Timer? _tickerTimer;
  int _secondsWaiting = 0;
  Position? _firstPosition;
  bool _hasTimedOut = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startPolling();
    _startTimeout();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _tickerTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async => _checkForPosition(),
    );
    _checkForPosition();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (_firstPosition == null && mounted) {
        setState(() => _hasTimedOut = true);
      }
    });
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _firstPosition != null) {
        timer.cancel();
        return;
      }
      setState(() => _secondsWaiting++);
    });
  }

  Future<void> _checkForPosition() async {
    if (!mounted || _firstPosition != null) return;
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    await traccar.refreshDevices();
    final position = traccar.getLastPosition(widget.device.traccarId!);
    if (position != null && mounted) {
      setState(() => _firstPosition = position);
      _pollTimer?.cancel();
      _timeoutTimer?.cancel();
      _tickerTimer?.cancel();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _navigateToGeofenceSetup(position);
    }
  }

  void _navigateToGeofenceSetup(Position position) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SetupGeofenceScreen(
          device: widget.device,
          petName: widget.petName,
          currentPosition: position,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasTimedOut) return _buildTimeoutView();
    if (_firstPosition != null) return _buildSuccessView();
    return _buildWaitingView();
  }

  // ============================================================== waiting

  Widget _buildWaitingView() {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(title: const Text('Buscando señal')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PettiSpacing.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: PettiColors.marigoldSoft,
                    borderRadius: BorderRadius.circular(PettiRadii.lg),
                  ),
                  child: const Icon(
                    Icons.satellite_alt_rounded,
                    size: 60,
                    color: PettiColors.marigold,
                  ),
                ),
              ),
              const SizedBox(height: PettiSpacing.s6),

              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: PettiSpacing.s4),

              Text(
                'Buscando señal GPS…',
                style: PettiText.h2(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PettiSpacing.s3),
              Text(
                'Asegúrate de que el collar esté:\n'
                '• Encendido y con batería\n'
                '• Al aire libre o cerca de una ventana\n'
                '• Con vista clara al cielo',
                style: PettiText.body().copyWith(
                  color: PettiColors.fgDim,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PettiSpacing.s5),

              // Live timer pill — Sand fill, monospace numerals.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PettiSpacing.s4,
                  vertical: PettiSpacing.s2,
                ),
                decoration: BoxDecoration(
                  color: PettiColors.sand,
                  borderRadius: BorderRadius.circular(PettiRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 16, color: PettiColors.fgDim),
                    const SizedBox(width: PettiSpacing.s2),
                    Text(
                      _formatTime(_secondsWaiting),
                      style:
                          PettiText.number(size: 14, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: PettiSpacing.s5),

              // Tip panel — Sabana-soft (calm "this is normal" tone).
              Container(
                padding: const EdgeInsets.all(PettiSpacing.s3),
                decoration: BoxDecoration(
                  color: PettiColors.sabanaSoft,
                  borderRadius: BorderRadius.circular(PettiRadii.sm),
                  border: Border.all(
                    color: PettiColors.sabana.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: PettiColors.sabana, size: 20),
                    const SizedBox(width: PettiSpacing.s3),
                    Expanded(
                      child: Text(
                        'La primera señal puede tardar 2–5 minutos.',
                        style: PettiText.bodySm()
                            .copyWith(color: PettiColors.midnight),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              TextButton(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                child: const Text('Omitir por ahora'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================== success

  Widget _buildSuccessView() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PettiColors.marigoldBright, PettiColors.marigold],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(PettiSpacing.s5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: PettiColors.cloud,
                      shape: BoxShape.circle,
                      boxShadow: PettiShadows.elevation2,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 72,
                      color: PettiColors.midnight,
                    ),
                  ),
                  const SizedBox(height: PettiSpacing.s6),

                  Text(
                    '¡Encontramos a ${widget.petName}!',
                    style: PettiText.h1().copyWith(
                      color: PettiColors.midnight,
                      fontSize: 30,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PettiSpacing.s3),
                  Text(
                    'Configurando rastreo en tiempo real…',
                    style: PettiText.body().copyWith(
                      color: PettiColors.midnight.withValues(alpha: 0.75),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (_firstPosition != null) ...[
                    const SizedBox(height: PettiSpacing.s5),
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: PettiSpacing.s4),
                      padding: const EdgeInsets.all(PettiSpacing.s4),
                      decoration: BoxDecoration(
                        color: PettiColors.midnight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(PettiRadii.md),
                      ),
                      child: Column(
                        children: [
                          _successInfo(
                            Icons.location_on_outlined,
                            _firstPosition!.coordinatesText,
                          ),
                          const SizedBox(height: PettiSpacing.s2),
                          _successInfo(
                            Icons.access_time_rounded,
                            _formatDateTime(_firstPosition!.deviceTime),
                          ),
                          if (_firstPosition!.accuracy != null) ...[
                            const SizedBox(height: PettiSpacing.s2),
                            _successInfo(
                              Icons.my_location_rounded,
                              '±${_firstPosition!.accuracy!.toStringAsFixed(0)} m de precisión',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successInfo(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: PettiColors.midnight),
        const SizedBox(width: PettiSpacing.s2),
        Text(
          text,
          style: PettiText.bodySm()
              .copyWith(color: PettiColors.midnight, fontSize: 13),
        ),
      ],
    );
  }

  // ============================================================== timeout

  Widget _buildTimeoutView() {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      appBar: AppBar(title: const Text('Sin señal')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PettiSpacing.s5),
          child: Column(
            children: [
              const SizedBox(height: PettiSpacing.s5),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: PettiColors.marigoldSoft,
                  borderRadius: BorderRadius.circular(PettiRadii.lg),
                ),
                child: const Icon(
                  Icons.signal_wifi_statusbar_connected_no_internet_4,
                  size: 56,
                  color: PettiColors.marigoldDim,
                ),
              ),
              const SizedBox(height: PettiSpacing.s5),

              Text(
                'No pudimos encontrar la señal',
                style: PettiText.h2(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PettiSpacing.s2),
              Text(
                'El collar aún no ha enviado su ubicación.',
                style: PettiText.body().copyWith(color: PettiColors.fgDim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PettiSpacing.s5),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(PettiSpacing.s4),
                decoration: BoxDecoration(
                  color: PettiColors.marigoldSoft,
                  borderRadius: BorderRadius.circular(PettiRadii.md),
                  border: Border.all(
                    color: PettiColors.marigold.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.help_outline,
                            color: PettiColors.marigoldDim, size: 22),
                        const SizedBox(width: PettiSpacing.s2),
                        Text('Soluciones', style: PettiText.h4()),
                      ],
                    ),
                    const SizedBox(height: PettiSpacing.s3),
                    _bullet('Verifica que el collar esté encendido'),
                    _bullet('Confirma que tenga batería suficiente'),
                    _bullet('Colócalo al aire libre por 5 minutos'),
                    _bullet('Asegúrate de que la SIM tenga datos activos'),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasTimedOut = false;
                      _secondsWaiting = 0;
                    });
                    _startPolling();
                    _startTimeout();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ),
              const SizedBox(height: PettiSpacing.s2),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                child: const Text('Configurar más tarde'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PettiSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.circle, size: 6, color: PettiColors.midnight),
          ),
          const SizedBox(width: PettiSpacing.s2),
          Expanded(
            child: Text(text, style: PettiText.body()),
          ),
        ],
      ),
    );
  }

  // ============================================================== format

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Hace unos segundos';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
