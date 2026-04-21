import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../models/geofence.dart';
import '../../providers/traccar_provider.dart';

/// Create or edit geofence screen
class GeofenceCreateScreen extends StatefulWidget {
  final Device device;
  final Geofence? editGeofence;

  const GeofenceCreateScreen({
    super.key,
    required this.device,
    this.editGeofence,
  });

  @override
  State<GeofenceCreateScreen> createState() => _GeofenceCreateScreenState();
}

class _GeofenceCreateScreenState extends State<GeofenceCreateScreen> {
  GoogleMapController? _mapController;
  late TextEditingController _nameController;
  
  double _radiusMeters = 100.0;
  LatLng? _center;
  bool _isCreating = false;
  
  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize controller
    if (widget.editGeofence != null) {
      _nameController = TextEditingController(text: widget.editGeofence!.name);
      _center = widget.editGeofence!.center;
      _radiusMeters = widget.editGeofence!.radius ?? 100.0;
    } else {
      _nameController = TextEditingController();
      _loadDevicePosition();
    }
    
    if (_center != null) {
      _updateCircle();
    }
  }

  Future<void> _loadDevicePosition() async {
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final position = traccar.getLastPosition(widget.device.traccarId!);
    
    if (position != null && mounted) {
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _updateCircle();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateCircle() {
    if (_center == null) return;

    _circles.clear();
    _circles.add(
      Circle(
        circleId: const CircleId('geofence'),
        center: _center!,
        radius: _radiusMeters,
        fillColor: const Color(0xFF2D6A4F).withOpacity(0.2),
        strokeColor: const Color(0xFF2D6A4F),
        strokeWidth: 2,
      ),
    );

    // Add center marker
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('center'),
        position: _center!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editGeofence != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Zona' : 'Crear Zona Segura'),
      ),
      body: _center == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center!,
                    zoom: 16,
                  ),
                  circles: _circles,
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onCameraMove: (position) {
                    setState(() {
                      _center = position.target;
                      _updateCircle();
                    });
                  },
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
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

                // Controls
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
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Name input
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la zona *',
                              hintText: 'Ej: Casa, Trabajo, Parque',
                              prefixIcon: Icon(Icons.location_on),
                              border: OutlineInputBorder(),
                            ),
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
                                    _formatRadius(_radiusMeters),
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
                                max: 1000,
                                divisions: 95,
                                label: _formatRadius(_radiusMeters),
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
                                    '1km',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Arrastra el mapa para posicionar el centro',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Save button
                          ElevatedButton(
                            onPressed: _isCreating ? null : _saveGeofence,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isCreating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    isEditing ? 'Guardar Cambios' : 'Crear Zona Segura',
                                    style: const TextStyle(fontSize: 16),
                                  ),
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

  String _formatRadius(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  Future<void> _saveGeofence() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un nombre para la zona'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_center == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al obtener ubicación'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final traccar = Provider.of<TraccarProvider>(context, listen: false);

    try {
      bool success;
      
      if (widget.editGeofence != null) {
        // Update existing geofence
        success = await traccar.updateGeofence(
          geofenceId: widget.editGeofence!.id,
          name: _nameController.text.trim(),
          area: _buildWKT(),
          deviceId: widget.device.traccarId!,
        );
      } else {
        // Create new geofence
        success = await traccar.createCircularGeofence(
          name: _nameController.text.trim(),
          latitude: _center!.latitude,
          longitude: _center!.longitude,
          radiusMeters: _radiusMeters,
          deviceId: widget.device.traccarId!,
        );
      }

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editGeofence != null
                  ? 'Zona actualizada correctamente'
                  : 'Zona creada correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(traccar.errorMessage ?? 'Error al guardar zona'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  String _buildWKT() {
    // Convert meters to degrees (approximate: 1 degree ≈ 111km)
    final radiusDegrees = _radiusMeters / 111000;
    return 'CIRCLE(${_center!.latitude} ${_center!.longitude} $radiusDegrees)';
  }
}
