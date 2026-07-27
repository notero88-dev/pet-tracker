// Geofence create / edit — Petti restyle.
//
// Map at top, draggable to position the circle's center, Petti bottom
// sheet with name + radius + drag-the-map hint + save CTA. Used both for
// "create new geofence" and "edit existing" — the editGeofence param
// distinguishes them.
//
// ALSO FIXES the lingering WKT CIRCLE bug in _buildWKT() (the same one
// fixed in TraccarProvider.createCircularGeofence in commit 4c07131).
// The edit path was still emitting "CIRCLE(lat lon degrees)" — meters-
// converted-to-degrees with a space separator — which Traccar reads as
// a 0.0009-meter geofence. Editing a geofence's radius from this screen
// would silently produce a tiny invisible zone. Now produces the
// correct "CIRCLE (LAT LON, RADIUS_METERS)" form.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/geofence.dart';
import '../../providers/traccar_provider.dart';
import '../../services/amplitude_service.dart';
import '../../utils/petti_theme.dart';

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

    if (widget.editGeofence != null) {
      _nameController = TextEditingController(text: widget.editGeofence!.name);
      _center = widget.editGeofence!.center;
      _radiusMeters = widget.editGeofence!.radius ?? 100.0;
    } else {
      _nameController = TextEditingController();
      _seedCenter();
    }
    if (_center != null) _updateOverlays();
  }

  /// Seed the initial pin. Priority (founder request 2026-07-27):
  ///   1. The PHONE's current location — the user is usually standing at
  ///      the place they want to protect, and this also works for
  ///      brand-new collars that have never reported.
  ///   2. The collar's last known position (previous behavior).
  ///   3. Bogotá city center — last resort so the map ALWAYS renders and
  ///      the user can drag the pin manually. Before this fallback chain,
  ///      a device with no position history left the screen on an
  ///      infinite spinner with no way to place the zone.
  /// The user then confirms by dragging the map (or leaving it as-is)
  /// before saving — the seed is only a starting point.
  Future<void> _seedCenter() async {
    final phoneFix = await _tryPhoneLocation();
    if (!mounted) return;
    if (phoneFix != null) {
      setState(() {
        _center = phoneFix;
        _updateOverlays();
      });
      return;
    }

    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final position = traccar.getLastPosition(widget.device.requireTraccarId());
    if (!mounted) return;
    setState(() {
      _center = position != null
          ? LatLng(position.latitude, position.longitude)
          : _bogotaFallback;
      _updateOverlays();
    });
  }

  /// Bogotá center — the app targets Colombia, so this puts first-run
  /// users with no permission + no device history in familiar territory
  /// instead of the Gulf of Guinea (0,0).
  static const LatLng _bogotaFallback = LatLng(4.6533, -74.0837);

  /// Phone GPS with the same permission dance the Zona de casa wizard
  /// uses. Returns null on any denial/failure — callers fall through to
  /// the next seed source. Bounded so a slow fix can't hold the map
  /// hostage: worst case ~8s then we fall back.
  Future<LatLng?> _tryPhoneLocation() async {
    try {
      final location = loc.Location();
      var perm = await location.hasPermission();
      if (perm == loc.PermissionStatus.denied) {
        perm = await location.requestPermission();
      }
      if (perm != loc.PermissionStatus.granted &&
          perm != loc.PermissionStatus.grantedLimited) {
        return null;
      }
      if (!await location.serviceEnabled()) return null;
      final fix =
          await location.getLocation().timeout(const Duration(seconds: 8));
      if (fix.latitude == null || fix.longitude == null) return null;
      return LatLng(fix.latitude!, fix.longitude!);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateOverlays() {
    if (_center == null) return;
    _circles
      ..clear()
      ..add(
        Circle(
          circleId: const CircleId('geofence'),
          center: _center!,
          radius: _radiusMeters,
          fillColor: PettiColors.sabana.withValues(alpha: 0.18),
          strokeColor: PettiColors.sabana,
          strokeWidth: 2,
        ),
      );
    // Marker is suppressed in favor of the floating crosshair pin so the
    // user has a clearer "drag the map to move the center" affordance.
    _markers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editGeofence != null;
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: PettiColors.cloud.withValues(alpha: 0.85),
        title: Text(isEditing ? 'Editar zona' : 'Nueva zona'),
        elevation: 0,
      ),
      body: _center == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center!,
                    zoom: 16,
                  ),
                  circles: _circles,
                  markers: _markers,
                  onMapCreated: (controller) =>
                      _mapController = controller,
                  onCameraMove: (cam) => setState(() {
                    _center = cam.target;
                    _updateOverlays();
                  }),
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                ),

                // Marigold center pin
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

                // Bottom sheet with form
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
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: PettiColors.fog,
                                borderRadius:
                                    BorderRadius.circular(PettiRadii.pill),
                              ),
                            ),
                          ),
                          const SizedBox(height: PettiSpacing.s4),

                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la zona *',
                              hintText: 'Ej: Casa, Trabajo, Parque',
                              prefixIcon:
                                  Icon(Icons.location_on_outlined),
                            ),
                          ),
                          const SizedBox(height: PettiSpacing.s4),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('RADIO', style: PettiText.meta()),
                              Text(
                                _formatRadius(_radiusMeters),
                                style: PettiText.number(
                                  size: 16,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: PettiColors.marigold,
                              inactiveTrackColor: PettiColors.fog,
                              thumbColor: PettiColors.marigold,
                              overlayColor: PettiColors.marigold
                                  .withValues(alpha: 0.2),
                            ),
                            child: Slider(
                              value: _radiusMeters,
                              min: 50,
                              max: 1000,
                              divisions: 95,
                              label: _formatRadius(_radiusMeters),
                              onChanged: (value) => setState(() {
                                _radiusMeters = value;
                                _updateOverlays();
                              }),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: PettiSpacing.s2),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('50 m',
                                    style: PettiText.bodySm().copyWith(
                                        color: PettiColors.fgDim)),
                                Text('1 km',
                                    style: PettiText.bodySm().copyWith(
                                        color: PettiColors.fgDim)),
                              ],
                            ),
                          ),
                          const SizedBox(height: PettiSpacing.s4),

                          // Drag-to-position hint — Sand surface, calm tone.
                          Container(
                            padding: const EdgeInsets.all(PettiSpacing.s3),
                            decoration: BoxDecoration(
                              color: PettiColors.sand,
                              borderRadius:
                                  BorderRadius.circular(PettiRadii.sm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.touch_app_outlined,
                                    size: 18, color: PettiColors.fgDim),
                                const SizedBox(width: PettiSpacing.s2),
                                Expanded(
                                  child: Text(
                                    'Arrastra el mapa para posicionar el centro',
                                    style: PettiText.bodySm().copyWith(
                                      color: PettiColors.fgDim,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: PettiSpacing.s4),

                          ElevatedButton(
                            onPressed:
                                _isCreating ? null : _saveGeofence,
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
                                : Text(
                                    isEditing
                                        ? 'Guardar cambios'
                                        : 'Crear zona segura',
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

  // ----------------------------------------------------------- formatting

  String _formatRadius(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  // ----------------------------------------------------------- actions

  Future<void> _saveGeofence() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre para la zona')),
      );
      return;
    }
    if (_center == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al obtener ubicación')),
      );
      return;
    }

    setState(() => _isCreating = true);
    final traccar = Provider.of<TraccarProvider>(context, listen: false);

    try {
      bool success;
      if (widget.editGeofence != null) {
        success = await traccar.updateGeofence(
          geofenceId: widget.editGeofence!.id,
          name: _nameController.text.trim(),
          area: _buildWKT(),
          deviceId: widget.device.requireTraccarId(),
        );
      } else {
        final geofenceId = await traccar.createCircularGeofence(
          name: _nameController.text.trim(),
          latitude: _center!.latitude,
          longitude: _center!.longitude,
          radiusMeters: _radiusMeters,
          deviceId: widget.device.requireTraccarId(),
        );
        success = geofenceId != null;
      }

      if (!mounted) return;
      if (success) {
        if (widget.editGeofence == null) {
          AmplitudeService.instance.track('Safe Zone Created', properties: {
            'radius_meters': _radiusMeters.round(),
            'device_imei': widget.device.uniqueId,
          });
        }
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editGeofence != null
                  ? 'Zona actualizada correctamente'
                  : 'Zona creada correctamente',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(traccar.errorMessage ?? 'Error al guardar zona'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  /// WKT for Traccar's geofence area. Format:
  ///   `CIRCLE (LAT LON, RADIUS_METERS)`
  /// Note: METERS, not degrees, and a comma between LON and RADIUS. The
  /// previous version of this method had it wrong — see the file header
  /// comment for context. Fixed in lockstep with TraccarProvider's
  /// createCircularGeofence (commit 4c07131).
  String _buildWKT() {
    return 'CIRCLE (${_center!.latitude} ${_center!.longitude}, $_radiusMeters)';
  }
}
