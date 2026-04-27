// Setup-first-geofence (onboarding) — Petti restyle.
//
// User just got their first GPS fix; this screen lets them drop a circle
// for "Casa" centered on the current position. Map at the top, Petti
// bottom sheet with a name field + radius slider + Marigold "Crear" CTA
// + skip option.
//
// Map circle uses Sabana (safe-zone color) instead of legacy green;
// fixed-position center crosshair becomes a Petti compass marker.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import '../../utils/petti_theme.dart';
import '../home/home_screen.dart';

class SetupGeofenceScreen extends StatefulWidget {
  final Device device;
  final String petName;
  final Position currentPosition;

  const SetupGeofenceScreen({
    super.key,
    required this.device,
    required this.petName,
    required this.currentPosition,
  });

  @override
  State<SetupGeofenceScreen> createState() => _SetupGeofenceScreenState();
}

class _SetupGeofenceScreenState extends State<SetupGeofenceScreen> {
  double _radiusMeters = 100.0;
  bool _isCreating = false;
  late TextEditingController _nameController;

  late LatLng _center;
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.currentPosition.latitude,
      widget.currentPosition.longitude,
    );
    _nameController = TextEditingController(text: 'Casa');
    _updateCircle();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateCircle() {
    _circles
      ..clear()
      ..add(
        Circle(
          circleId: const CircleId('geofence'),
          center: _center,
          radius: _radiusMeters,
          fillColor: PettiColors.sabana.withValues(alpha: 0.18),
          strokeColor: PettiColors.sabana,
          strokeWidth: 2,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      // Floating app-bar effect — translucent over the map.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: PettiColors.cloud.withValues(alpha: 0.85),
        title: const Text('Tu zona segura'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            circles: _circles,
            onMapCreated: (_) {},
            onCameraMove: (cam) => setState(() {
              _center = cam.target;
              _updateCircle();
            }),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Center crosshair — Marigold pin so it pops against any map style.
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PettiColors.marigold,
                  shape: BoxShape.circle,
                  boxShadow: PettiShadows.elevation1,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: PettiColors.midnight,
                  size: 22,
                ),
              ),
            ),
          ),

          // Bottom sheet — Petti panel with name + radius + CTAs.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: PettiColors.cloud,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PettiRadii.lg),
                  ),
                  boxShadow: PettiShadows.elevation2,
                ),
                padding: const EdgeInsets.fromLTRB(
                  PettiSpacing.s5,
                  PettiSpacing.s5,
                  PettiSpacing.s5,
                  PettiSpacing.s4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pull handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PettiColors.fog,
                          borderRadius: BorderRadius.circular(PettiRadii.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: PettiSpacing.s4),

                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: PettiColors.sabanaSoft,
                            borderRadius: BorderRadius.circular(PettiRadii.sm),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: PettiColors.sabana,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: PettiSpacing.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tu primera zona segura',
                                style: PettiText.h4(),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Recibirás una alerta si ${widget.petName} sale de aquí',
                                style: PettiText.bodySm()
                                    .copyWith(color: PettiColors.fgDim),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PettiSpacing.s4),

                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la zona',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: PettiSpacing.s4),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('RADIO', style: PettiText.meta()),
                        Text(
                          '${_radiusMeters.toInt()} m',
                          style: PettiText.number(
                            size: 16,
                            weight: FontWeight.w700,
                          ).copyWith(color: PettiColors.midnight),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: PettiColors.marigold,
                        inactiveTrackColor: PettiColors.fog,
                        thumbColor: PettiColors.marigold,
                        overlayColor:
                            PettiColors.marigold.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _radiusMeters,
                        min: 50,
                        max: 500,
                        divisions: 45,
                        label: '${_radiusMeters.toInt()} m',
                        onChanged: (value) => setState(() {
                          _radiusMeters = value;
                          _updateCircle();
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: PettiSpacing.s2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('50 m',
                              style: PettiText.bodySm()
                                  .copyWith(color: PettiColors.fgDim)),
                          Text('500 m',
                              style: PettiText.bodySm()
                                  .copyWith(color: PettiColors.fgDim)),
                        ],
                      ),
                    ),
                    const SizedBox(height: PettiSpacing.s5),

                    ElevatedButton(
                      onPressed: _isCreating ? null : _createGeofence,
                      child: _isCreating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                    PettiColors.midnight),
                              ),
                            )
                          : const Text('Crear zona segura'),
                    ),
                    const SizedBox(height: PettiSpacing.s2),
                    TextButton(
                      onPressed: _skipToHome,
                      child: const Text('Omitir por ahora'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- actions

  Future<void> _createGeofence() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Ingresa un nombre para la zona');
      return;
    }

    setState(() => _isCreating = true);
    final traccar = Provider.of<TraccarProvider>(context, listen: false);

    try {
      final geofenceId = await traccar.createCircularGeofence(
        name: name,
        latitude: _center.latitude,
        longitude: _center.longitude,
        radiusMeters: _radiusMeters,
        deviceId: widget.device.traccarId!,
      );
      if (geofenceId != null) {
        _showSuccess();
      } else {
        _showError(traccar.errorMessage ?? 'Error al crear zona');
      }
    } catch (e) {
      _showError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showSuccess() {
    final name = _nameController.text.trim();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PettiColors.sabanaSoft,
                borderRadius: BorderRadius.circular(PettiRadii.sm),
              ),
              child: const Icon(Icons.check_rounded,
                  color: PettiColors.sabana, size: 20),
            ),
            const SizedBox(width: PettiSpacing.s3),
            const Text('¡Listo!'),
          ],
        ),
        content: Text(
          'Tu zona segura "$name" ha sido creada.\n\n'
          'Recibirás una notificación si ${widget.petName} sale de esta zona.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToHome();
            },
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _skipToHome() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Omitir zona segura?'),
        content: const Text(
          'Puedes crear zonas seguras más tarde desde el menú principal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToHome();
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }
}
