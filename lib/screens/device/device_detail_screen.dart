// Device detail (live map) — Petti restyle.
//
// The most-used screen daily. Layout:
//   - Full-bleed Google Map (markers + optional history polyline)
//   - Floating header card at top (back, name + status, EN VIVO pill,
//     zonas, refresh, gear icon for Petti DeviceSettings)
//   - Floating bottom info card with address + 3 stat cards + LIVE/
//     historial action row
//   - Floating "comandos" FAB (legacy DeviceCommandsSheet shortcut —
//     left as-is since DeviceSettings already covers most flows)
//   - History viewer slides up from the bottom when "Historial" is
//     tapped; the bottom info card hides while it's showing
//
// Big visual swaps from the legacy version:
//   - Hardcoded green #2D6A4F → PettiColors.midnight / sabana
//   - LIVE pill: red → Marigold (Petti "active state" convention,
//     not danger). The animated white dot stays for "live" feel.
//   - Stat cards: legacy grey-fill / bold-black → Sand surface,
//     PettiText.meta() label, PettiText.number() value
//   - Battery color helper: Sabana / Marigold / Alert thresholds
//     instead of pure RGB values
//   - History trail polyline: Sabana with translucency
//   - Header + bottom panel use elevation-1 Petti shadow

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../models/position.dart';
import '../../providers/traccar_provider.dart';
import '../../utils/constants.dart';
import '../../utils/petti_theme.dart';
import '../../widgets/device_commands_sheet.dart';
import '../../widgets/position_history_viewer.dart';
import '../geofence/geofence_list_screen.dart';
import 'device_settings_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

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

  // ----------------------------------------------------- data

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
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(seconds: AppConstants.normalUpdateIntervalSeconds),
      (_) => _refreshPosition(),
    );
  }

  void _startLiveUpdates() {
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
        // Marigold-hued marker so the live dot matches the brand.
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: widget.device.name,
          snippet: position.address ?? position.coordinatesText,
        ),
      ),
    );
  }

  void _toggleLiveMode() {
    setState(() => _isLiveMode = !_isLiveMode);

    if (_isLiveMode) {
      _startLiveUpdates();
      final traccar = Provider.of<TraccarProvider>(context, listen: false);
      traccar.requestPositionNow(widget.device.traccarId!);
    } else {
      _startNormalUpdates();
    }
  }

  // ----------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            DeviceCommandsSheet.show(context, widget.device),
        backgroundColor: PettiColors.midnight,
        foregroundColor: PettiColors.cloud,
        tooltip: 'Comandos',
        child: const Icon(Icons.settings_remote_outlined),
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
                  onMapCreated: (controller) =>
                      _mapController = controller,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: PettiSpacing.s4),
                      Text(
                        'Cargando ubicación…',
                        style: PettiText.body()
                            .copyWith(color: PettiColors.fgDim),
                      ),
                    ],
                  ),
                ),

          // Top header card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildHeader()),
          ),

          // History viewer (when active)
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

          // Bottom info panel (when not showing history)
          if (_currentPosition != null && !_showHistory)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: _buildBottomPanel()),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------- header card

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: PettiColors.cloud,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        boxShadow: PettiShadows.elevation1,
        border: Border.all(color: PettiColors.borderLight),
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
                  style: PettiText.h4(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.device.statusText,
                  style: PettiText.bodySm().copyWith(
                    color: widget.device.isOnline
                        ? PettiColors.sabana
                        : PettiColors.fgDim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_isLiveMode)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PettiSpacing.s3,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: PettiColors.marigold,
                borderRadius: BorderRadius.circular(PettiRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PettiColors.midnight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'EN VIVO',
                    style: PettiText.meta().copyWith(
                      color: PettiColors.midnight,
                      letterSpacing: 0.04 * 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: PettiSpacing.s2),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Zonas seguras',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    GeofenceListScreen(device: widget.device),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshPosition,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes del dispositivo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceSettingsScreen(
                  device: widget.device,
                  petName: widget.device.name,
                  isOnline: _currentPosition != null,
                  lastSeen: _currentPosition?.deviceTime,
                  batteryPercent: _currentPosition
                          ?.attributes?['batteryLevel'] as int? ??
                      80,
                ),
              ),
            ),
          ),
          const SizedBox(width: PettiSpacing.s1),
        ],
      ),
    );
  }

  // ----------------------------------------------------- bottom panel

  Widget _buildBottomPanel() {
    final pos = _currentPosition!;
    return Container(
      margin: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: PettiColors.cloud,
        borderRadius: BorderRadius.circular(PettiRadii.md),
        boxShadow: PettiShadows.elevation1,
        border: Border.all(color: PettiColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(PettiSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: PettiColors.sabana,
                      size: 20,
                    ),
                    const SizedBox(width: PettiSpacing.s2),
                    Expanded(
                      child: Text(
                        pos.address ?? pos.coordinatesText,
                        style: PettiText.bodyStrong()
                            .copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PettiSpacing.s3),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.access_time_rounded,
                        label: 'Actualizado',
                        value: _formatTimestamp(pos.deviceTime),
                      ),
                    ),
                    const SizedBox(width: PettiSpacing.s2),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.speed_rounded,
                        label: 'Velocidad',
                        value: pos.speedText,
                      ),
                    ),
                    if (pos.batteryLevel != null) ...[
                      const SizedBox(width: PettiSpacing.s2),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.battery_charging_full_rounded,
                          label: 'Batería',
                          value: '${pos.batteryLevel}%',
                          valueColor:
                              _batteryColor(pos.batteryLevel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Action row — Sand surface, two equal-width buttons.
          Container(
            padding: const EdgeInsets.all(PettiSpacing.s3),
            decoration: const BoxDecoration(
              color: PettiColors.sand,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(PettiRadii.md),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleLiveMode,
                    icon: Icon(
                      _isLiveMode
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _isLiveMode ? 'Detener' : 'Modo LIVE',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isLiveMode
                          ? PettiColors.alert
                          : PettiColors.midnight,
                      side: BorderSide(
                        color: _isLiveMode
                            ? PettiColors.alert
                            : PettiColors.midnight,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: PettiSpacing.s2),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showHistory ? _closeHistory : _loadHistory,
                    icon: Icon(
                      _showHistory
                          ? Icons.close_rounded
                          : Icons.history_rounded,
                    ),
                    label:
                        Text(_showHistory ? 'Cerrar' : 'Historial'),
                  ),
                ),
              ],
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
    return Container(
      padding: const EdgeInsets.all(PettiSpacing.s3),
      decoration: BoxDecoration(
        color: PettiColors.sand,
        borderRadius: BorderRadius.circular(PettiRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: PettiColors.fgDim),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: PettiText.meta().copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: PettiText.number(size: 14, weight: FontWeight.w700)
                .copyWith(
              color: valueColor ?? PettiColors.midnight,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Color _batteryColor(int level) {
    if (level >= 60) return PettiColors.sabana;
    if (level >= AppConstants.batteryLowThreshold) {
      return PettiColors.marigoldDim;
    }
    return PettiColors.alert;
  }

  // ----------------------------------------------------- history

  Future<void> _loadHistory() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    final traccar = Provider.of<TraccarProvider>(context, listen: false);
    final history = await traccar.loadPositionHistory(
      deviceId: widget.device.traccarId!,
      from: yesterday,
      to: now,
    );

    if (!mounted) return;
    setState(() {
      _historyPositions = history;
      _showHistory = true;
      _drawHistoryTrail();
    });
  }

  void _drawHistoryTrail() {
    if (_historyPositions.isEmpty) return;

    final points = _historyPositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    _polylines
      ..clear()
      ..add(
        Polyline(
          polylineId: const PolylineId('history_trail'),
          points: points,
          color: PettiColors.sabana.withValues(alpha: 0.7),
          width: 4,
          geodesic: true,
        ),
      );

    if (_historyPositions.length > 1) {
      final start = _historyPositions.last;
      final end = _historyPositions.first;

      _markers.add(
        Marker(
          markerId: const MarkerId('history_start'),
          position: LatLng(start.latitude, start.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Inicio'),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('history_end'),
          position: LatLng(end.latitude, end.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Actual'),
        ),
      );
    }

    if (_mapController != null && _historyPositions.length > 1) {
      final bounds = _calculateBounds(_historyPositions);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  LatLngBounds _calculateBounds(List<Position> positions) {
    double? minLat, maxLat, minLng, maxLng;
    for (final pos in positions) {
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
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
      _markers
          .removeWhere((m) => m.markerId.value == 'selected_history');
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_history'),
          position: LatLng(position.latitude, position.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
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
      if (_currentPosition != null) {
        _updateMarker(_currentPosition!);
      }
    });
  }
}
