import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import 'setup_geofence_screen.dart';

/// Screen waiting for first GPS position
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
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startPolling();
    _startTimeout();
  }

  void _startPolling() {
    // Poll every 5 seconds for position
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkForPosition();
    });

    // Initial check
    _checkForPosition();
  }

  void _startTimeout() {
    // Timeout after 5 minutes
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (_firstPosition == null && mounted) {
        setState(() => _hasTimedOut = true);
      }
    });

    // Update seconds counter
    Timer.periodic(const Duration(seconds: 1), (timer) {
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
    
    // Refresh devices to get latest position
    await traccar.refreshDevices();
    
    final position = traccar.getLastPosition(widget.device.traccarId!);
    
    if (position != null && mounted) {
      setState(() => _firstPosition = position);
      _pollTimer?.cancel();
      _timeoutTimer?.cancel();
      
      // Wait a bit to show success, then navigate
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        _navigateToGeofenceSetup(position);
      }
    }
  }

  void _navigateToGeofenceSetup(Position position) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SetupGeofenceScreen(
          device: widget.device,
          petName: widget.petName,
          currentPosition: position,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasTimedOut) {
      return _buildTimeoutView();
    }

    if (_firstPosition != null) {
      return _buildSuccessView();
    }

    return _buildWaitingView();
  }

  Widget _buildWaitingView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Esperando señal GPS'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated GPS icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.satellite_alt,
                  size: 64,
                  color: Color(0xFF2D6A4F),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Loading indicator
            const CircularProgressIndicator(),
            const SizedBox(height: 24),

            // Title
            Text(
              'Buscando señal GPS...',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Instructions
            Text(
              'Asegúrate de que el dispositivo esté:\n'
              '• Encendido y con batería\n'
              '• Al aire libre o cerca de una ventana\n'
              '• Con vista clara al cielo',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Timer
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(_secondsWaiting),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'La primera señal puede tardar 2-5 minutos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Skip button (for testing)
            TextButton(
              onPressed: () {
                // For development: skip to home
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Omitir por ahora'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Color(0xFF2D6A4F),
                ),
              ),
              const SizedBox(height: 32),

              // Success message
              const Text(
                '¡Señal GPS encontrada!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                '${widget.petName} está listo para ser rastreado',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Position info
              if (_firstPosition != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.location_on,
                        _firstPosition!.coordinatesText,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.access_time,
                        _formatDateTime(_firstPosition!.deviceTime),
                      ),
                      if (_firstPosition!.accuracy != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildInfoRow(
                            Icons.my_location,
                            '±${_firstPosition!.accuracy!.toStringAsFixed(0)}m precisión',
                          ),
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

  Widget _buildTimeoutView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sin señal GPS'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.signal_wifi_statusbar_connected_no_internet_4,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 32),

            const Text(
              'No se pudo obtener señal GPS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              'El dispositivo no ha enviado su ubicación aún.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Troubleshooting
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Soluciones',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildBullet('Verifica que el dispositivo esté encendido'),
                  _buildBullet('Confirma que tenga batería suficiente'),
                  _buildBullet('Colócalo al aire libre por 5 minutos'),
                  _buildBullet('Asegúrate de que la SIM tenga datos activos'),
                ],
              ),
            ),
            const Spacer(),

            // Action buttons
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasTimedOut = false;
                  _secondsWaiting = 0;
                });
                _startPolling();
                _startTimeout();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Configurar más tarde'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
}
