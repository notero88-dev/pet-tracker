import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import '../home/home_screen.dart';

/// Setup first geofence screen
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
  GoogleMapController? _mapController;
  double _radiusMeters = 100.0; // Default 100m
  bool _isCreating = false;
  String _geofenceName = 'Casa';

  late LatLng _center;
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.currentPosition.latitude,
      widget.currentPosition.longitude,
    );
    _updateCircle();
  }

  void _updateCircle() {
    _circles.clear();
    _circles.add(
      Circle(
        circleId: const CircleId('geofence'),
        center: _center,
        radius: _radiusMeters,
        fillColor: const Color(0xFF2D6A4F).withOpacity(0.2),
        strokeColor: const Color(0xFF2D6A4F),
        strokeWidth: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zona Segura'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 16,
            ),
            circles: _circles,
            markers: {
              Marker(
                markerId: const MarkerId('pet'),
                position: _center,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
            },
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (position) {
              // Update center as user moves map
              setState(() {
                _center = position.target;
                _updateCircle();
              });
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Controls overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6A4F).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield,
                          color: Color(0xFF2D6A4F),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crea tu primera zona segura',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Recibirás alertas si sale de esta zona',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Name input
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la zona',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _geofenceName = value);
                    },
                    controller: TextEditingController(text: _geofenceName),
                  ),
                  const SizedBox(height: 16),

                  // Radius slider
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Radio de la zona',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_radiusMeters.toInt()}m',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D6A4F),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _radiusMeters,
                        min: 50,
                        max: 500,
                        divisions: 45,
                        label: '${_radiusMeters.toInt()}m',
                        onChanged: (value) {
                          setState(() {
                            _radiusMeters = value;
                            _updateCircle();
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '50m',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '500m',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Create button
                  ElevatedButton(
                    onPressed: _isCreating ? null : _createGeofence,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Crear Zona Segura',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 8),

                  // Skip button
                  TextButton(
                    onPressed: _skipToHome,
                    child: const Text('Omitir por ahora'),
                  ),
                ],
              ),
            ),
          ),

          // Center crosshair
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 32,
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createGeofence() async {
    if (_geofenceName.trim().isEmpty) {
      _showError('Ingresa un nombre para la zona');
      return;
    }

    setState(() => _isCreating = true);

    final traccar = Provider.of<TraccarProvider>(context, listen: false);

    try {
      // Returns the new geofence id on success or null on failure.
      final geofenceId = await traccar.createCircularGeofence(
        name: _geofenceName.trim(),
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
      setState(() => _isCreating = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('¡Listo!'),
          ],
        ),
        content: Text(
          'Tu zona segura "$_geofenceName" ha sido creada.\n\n'
          'Recibirás una notificación si ${widget.petName} sale de esta zona.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _goToHome();
            },
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _skipToHome() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Omitir zona segura?'),
        content: const Text(
          'Puedes crear zonas seguras más tarde desde la pantalla principal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }
}
