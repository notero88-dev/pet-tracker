import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/position_history_viewer.dart';
import '../../widgets/device_commands_sheet.dart';
import '../geofence/geofence_list_screen.dart';

/// Device detail screen with live map
class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({
    super.key,
    required this.device,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  GoogleMapController? _mapController;
  Timer? _updateTimer;
  bool _isLiveMode = false;
  bool _showHistory = false;
  
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  Position? _currentPosition;
  List<Position> _historyPositions = [];
  Position? _selectedHistoryPosition;

  @override
  void initState() {
    super.initState();
    _loadCurrentPosition();
    _startNormalUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _loadCurrentPosition() {
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final position = traccar.getLastPosition(widget.device.traccarId!);
    if (position != null) {
      setState(() {
        _currentPosition = position;
        _updateMarker(position);
      });
    }
  }

  void _startNormalUpdates() {
    // Update every 5 minutes (300 seconds)
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(seconds: AppConstants.normalUpdateIntervalSeconds),
      (_) => _refreshPosition(),
    );
  }

  void _startLiveUpdates() {
    // Update every 10 seconds
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(seconds: AppConstants.liveUpdateIntervalSeconds),
      (_) => _refreshPosition(),
    );
  }

  Future<void> _refreshPosition() async {
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    await traccar.refreshDevices();
    
    final position = traccar.getLastPosition(widget.device.traccarId!);
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
        _updateMarker(position);
        
        // Move camera to new position
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      });
    }
  }

  void _updateMarker(Position position) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: MarkerId('pet-${widget.device.id}'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: widget.device.name,
          snippet: position.address ?? position.coordinatesText,
        ),
      ),
    );
  }

  void _toggleLiveMode() {
    setState(() {
      _isLiveMode = !_isLiveMode;
    });

    if (_isLiveMode) {
      _startLiveUpdates();
      // Request immediate position
      final traccar = Provider.of<TraccarProvider>(context, listen: false);
      traccar.requestPositionNow(widget.device.traccarId!);
    } else {
      _startNormalUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => DeviceCommandsSheet.show(context, widget.device),
        tooltip: 'Comandos',
        child: const Icon(Icons.settings_remote),
      ),
      body: Stack(
        children: [
          // Map
          _currentPosition != null
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: AppConstants.defaultZoom,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cargando ubicación...'),
                    ],
                  ),
                ),

          // Top app bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.device.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.device.statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.device.isOnline
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // LIVE mode indicator
                    if (_isLiveMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'EN VIVO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.shield),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GeofenceListScreen(device: widget.device),
                          ),
                        );
                      },
                      tooltip: 'Zonas Seguras',
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshPosition,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // History viewer (replaces bottom panel when active)
          if (_showHistory)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: PositionHistoryViewer(
                  positions: _historyPositions,
                  selectedPosition: _selectedHistoryPosition,
                  onPositionSelected: _onHistoryPositionSelected,
                  onClose: _closeHistory,
                ),
              ),
            ),

          // Bottom info panel (hidden when history is showing)
          if (_currentPosition != null && !_showHistory)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Position info
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Address or coordinates
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF2D6A4F),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _currentPosition!.address ??
                                        _currentPosition!.coordinatesText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Stats grid
                            Row(
                              children: [
                                _buildStatCard(
                                  icon: Icons.access_time,
                                  label: 'Actualizado',
                                  value: _formatTimestamp(
                                    _currentPosition!.deviceTime,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatCard(
                                  icon: Icons.speed,
                                  label: 'Velocidad',
                                  value: _currentPosition!.speedText,
                                ),
                                const SizedBox(width: 8),
                                if (_currentPosition!.batteryLevel != null)
                                  _buildStatCard(
                                    icon: Icons.battery_charging_full,
                                    label: 'Batería',
                                    value: '${_currentPosition!.batteryLevel}%',
                                    valueColor: _getBatteryColor(
                                      _currentPosition!.batteryLevel!,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Action buttons
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _toggleLiveMode,
                                icon: Icon(
                                  _isLiveMode ? Icons.stop : Icons.play_arrow,
                                ),
                                label: Text(
                                  _isLiveMode ? 'Detener LIVE' : 'Modo LIVE',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _isLiveMode
                                      ? Colors.red
                                      : const Color(0xFF2D6A4F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showHistory ? _closeHistory : _loadHistory,
                                icon: Icon(_showHistory ? Icons.close : Icons.history),
                                label: Text(_showHistory ? 'Cerrar' : 'Historial'),
                              ),
                            ),
                          ],
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

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Ahora';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inDays}d';
    }
  }

  Color _getBatteryColor(int level) {
    if (level >= 60) return Colors.green;
    if (level >= AppConstants.batteryLowThreshold) return Colors.orange;
    return Colors.red;
  }

  Future<void> _loadHistory() async {
    // Load last 24 hours of history
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    
    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final history = await traccar.loadPositionHistory(
      deviceId: widget.device.traccarId!,
      from: yesterday,
      to: now,
    );

    if (mounted) {
      setState(() {
        _historyPositions = history;
        _showHistory = true;
        _drawHistoryTrail();
      });
    }
  }

  void _drawHistoryTrail() {
    if (_historyPositions.isEmpty) return;

    // Create polyline from history
    final points = _historyPositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('history_trail'),
        points: points,
        color: const Color(0xFF2D6A4F).withOpacity(0.6),
        width: 4,
        geodesic: true,
      ),
    );

    // Add markers for start and end
    if (_historyPositions.length > 1) {
      final start = _historyPositions.last;
      final end = _historyPositions.first;

      _markers.add(
        Marker(
          markerId: const MarkerId('history_start'),
          position: LatLng(start.latitude, start.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Inicio'),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('history_end'),
          position: LatLng(end.latitude, end.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Actual'),
        ),
      );
    }

    // Fit bounds to show all positions
    if (_mapController != null && _historyPositions.length > 1) {
      final bounds = _calculateBounds(_historyPositions);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  LatLngBounds _calculateBounds(List<Position> positions) {
    double? minLat, maxLat, minLng, maxLng;

    for (var pos in positions) {
      if (minLat == null || pos.latitude < minLat) minLat = pos.latitude;
      if (maxLat == null || pos.latitude > maxLat) maxLat = pos.latitude;
      if (minLng == null || pos.longitude < minLng) minLng = pos.longitude;
      if (maxLng == null || pos.longitude > maxLng) maxLng = pos.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  void _onHistoryPositionSelected(Position position) {
    setState(() {
      _selectedHistoryPosition = position;
      
      // Move camera to selected position
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );

      // Add temporary marker for selected position
      _markers.removeWhere((m) => m.markerId.value == 'selected_history');
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_history'),
          position: LatLng(position.latitude, position.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: 'Posición seleccionada',
            snippet: position.address ?? position.coordinatesText,
          ),
        ),
      );
    });
  }

  void _closeHistory() {
    setState(() {
      _showHistory = false;
      _historyPositions = [];
      _selectedHistoryPosition = null;
      _polylines.clear();
      
      // Restore current position marker
      if (_currentPosition != null) {
        _updateMarker(_currentPosition!);
      }
    });
  }
}
