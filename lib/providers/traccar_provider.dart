import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/traccar_event.dart';
import '../models/geofence.dart';
import '../services/traccar_api.dart';
import '../services/traccar_websocket.dart';
import '../services/provisioning_api.dart';

/// Provider for Traccar connection and real-time updates
class TraccarProvider with ChangeNotifier {
  final TraccarApi _api = TraccarApi();
  final TraccarWebSocket _ws = TraccarWebSocket();
  final ProvisioningApi _provisioningApi = ProvisioningApi();

  List<Device> _devices = [];
  Map<int, Position> _lastPositions = {}; // deviceId -> Position
  Map<int, List<Position>> _positionHistory = {}; // deviceId -> List<Position>
  List<TraccarEvent> _recentEvents = [];
  List<Geofence> _geofences = [];
  
  bool _isConnected = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<TraccarEvent>? _eventSubscription;

  // Getters
  List<Device> get devices => _devices;
  Map<int, Position> get lastPositions => _lastPositions;
  List<Geofence> get geofences => _geofences;
  Map<int, List<Position>> get positionHistory => _positionHistory;
  List<TraccarEvent> get recentEvents => _recentEvents;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Initialize connection to Traccar
  Future<bool> connect(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Login to Traccar
      final success = await _api.login(email, password);
      
      if (success) {
        _isConnected = true;
        
        // Connect WebSocket for real-time updates
        await _ws.connect();
        
        // Subscribe to real-time position updates
        _positionSubscription = _ws.positionStream.listen(_handlePositionUpdate);
        
        // Subscribe to events
        _eventSubscription = _ws.eventStream.listen(_handleEventUpdate);
        
        // Load initial devices and positions
        await refreshDevices();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Credenciales inválidas';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Handle real-time position update from WebSocket
  void _handlePositionUpdate(Position position) {
    _lastPositions[position.deviceId] = position;
    
    // Add to history
    if (!_positionHistory.containsKey(position.deviceId)) {
      _positionHistory[position.deviceId] = [];
    }
    _positionHistory[position.deviceId]!.insert(0, position);
    
    // Keep only last 100 positions in memory
    if (_positionHistory[position.deviceId]!.length > 100) {
      _positionHistory[position.deviceId]!.removeLast();
    }
    
    notifyListeners();
  }

  /// Handle real-time event update from WebSocket
  void _handleEventUpdate(TraccarEvent event) {
    _recentEvents.insert(0, event);
    
    // Keep only last 50 events
    if (_recentEvents.length > 50) {
      _recentEvents.removeLast();
    }
    
    notifyListeners();
    
    // TODO: Trigger push notification if event.shouldNotify
  }

  /// Refresh devices list
  Future<void> refreshDevices() async {
    try {
      _devices = await _api.getDevices();
      
      // Load last position for each device
      for (var device in _devices) {
        if (device.traccarId != null) {
          final position = await _api.getLastPosition(device.traccarId!);
          if (position != null) {
            _lastPositions[device.traccarId!] = position;
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar dispositivos: $e';
      notifyListeners();
    }
  }

  /// Get position history for a device
  Future<List<Position>> loadPositionHistory({
    required int deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final history = await _api.getPositionHistory(
        deviceId: deviceId,
        from: from,
        to: to,
      );
      
      _positionHistory[deviceId] = history;
      notifyListeners();
      return history;
    } catch (e) {
      _errorMessage = 'Error al cargar historial: $e';
      notifyListeners();
      return [];
    }
  }

  /// Provision a new device
  Future<Device?> provisionDevice({
    required String imei,
    required String deviceName,
    required String userId,
    required String userEmail,
    required String petName,
    required String petType,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final device = await _provisioningApi.provisionDevice(
        imei: imei,
        name: deviceName,
        userId: userId,
        userEmail: userEmail,
        petName: petName,
        petType: petType,
      );
      
      await refreshDevices(); // Reload device list
      
      _isLoading = false;
      notifyListeners();
      return device;
    } catch (e) {
      _errorMessage = 'Error al aprovisionar: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
  
  /// Get Traccar credentials from last provisioning
  Map<String, dynamic>? getLastProvisionedCredentials() {
    return _provisioningApi.getLastProvisionedCredentials();
  }

  /// Create circular geofence
  Future<bool> createCircularGeofence({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required int deviceId,
  }) async {
    try {
      // WKT CIRCLE format: "CIRCLE(lat lon radius_in_degrees)"
      // Convert meters to degrees (approximate: 1 degree ≈ 111km)
      final radiusDegrees = radiusMeters / 111000;
      final area = 'CIRCLE($latitude $longitude $radiusDegrees)';
      
      final geofence = await _api.createGeofence(
        name: name,
        area: area,
      );
      
      if (geofence != null) {
        // Link to device
        await _api.linkGeofenceToDevice(geofence['id'], deviceId);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error al crear zona: $e';
      notifyListeners();
      return false;
    }
  }

  /// Request immediate position update
  Future<void> requestPositionNow(int deviceId) async {
    try {
      await _provisioningApi.requestPosition(deviceId);
    } catch (e) {
      _errorMessage = 'Error al solicitar posición: $e';
      notifyListeners();
    }
  }

  /// Set update interval for device
  Future<void> setUpdateInterval(int deviceId, int seconds) async {
    try {
      await _provisioningApi.setUpdateInterval(deviceId, seconds);
    } catch (e) {
      _errorMessage = 'Error al cambiar intervalo: $e';
      notifyListeners();
    }
  }

  /// Get device by ID
  Device? getDevice(int deviceId) {
    try {
      return _devices.firstWhere((d) => d.traccarId == deviceId);
    } catch (e) {
      return null;
    }
  }

  /// Get last position for device
  Position? getLastPosition(int deviceId) {
    return _lastPositions[deviceId];
  }

  /// Load all geofences
  Future<void> loadGeofences() async {
    try {
      final geofencesData = await _api.getGeofences();
      _geofences = geofencesData.map((json) => Geofence.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar geocercas: $e';
      notifyListeners();
    }
  }

  /// Get geofences for a specific device
  List<Geofence> getGeofencesForDevice(int deviceId) {
    return _geofences.where((g) => g.deviceId == deviceId || g.deviceId == null).toList();
  }

  /// Delete geofence
  Future<bool> deleteGeofence(int geofenceId) async {
    try {
      final success = await _api.deleteGeofence(geofenceId);
      if (success) {
        _geofences.removeWhere((g) => g.id == geofenceId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error al eliminar geocerca: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update geofence (delete + recreate)
  Future<bool> updateGeofence({
    required int geofenceId,
    required String name,
    required String area,
    int? deviceId,
  }) async {
    try {
      // Delete old geofence
      await _api.deleteGeofence(geofenceId);
      
      // Create new geofence
      final newGeofence = await _api.createGeofence(
        name: name,
        area: area,
      );
      
      if (newGeofence != null && deviceId != null) {
        await _api.linkGeofenceToDevice(newGeofence['id'], deviceId);
      }
      
      // Reload geofences
      await loadGeofences();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar geocerca: $e';
      notifyListeners();
      return false;
    }
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _positionSubscription?.cancel();
    await _eventSubscription?.cancel();
    await _ws.disconnect();
    await _api.logout();
    
    _isConnected = false;
    _devices = [];
    _lastPositions = {};
    _positionHistory = {};
    _recentEvents = [];
    
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
