import 'dart:async';
import 'dart:collection' show UnmodifiableListView, UnmodifiableMapView;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../models/traccar_event.dart';
import '../models/geofence.dart';
import '../services/traccar_api.dart';
import '../services/traccar_websocket.dart';
import '../services/provisioning_api.dart';

/// Surfaced via TraccarProvider.connectionStatus so screens (En vivo
/// in particular) can show a "Reconectando…" badge while the socket
/// is being re-established. `connecting` is the initial-login path;
/// `reconnecting` means we lost a previously-good socket and are
/// attempting to recover. Tying the badge to a separate state avoids
/// flashing the indicator during a healthy first login.
enum TraccarConnectionStatus { disconnected, connecting, connected, reconnecting }

/// Provider for Traccar connection and real-time updates
class TraccarProvider with ChangeNotifier, WidgetsBindingObserver {
  TraccarProvider() {
    // Reconnect on app resume — iOS aggressively suspends background
    // sockets, and even foreground sockets can die on Wi-Fi ↔ cellular
    // handoffs. Without this, En vivo silently goes stale until the
    // user fully closes and re-enters the screen.
    WidgetsBinding.instance.addObserver(this);
  }

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
  StreamSubscription<String>? _statusSubscription;

  // Reconnect bookkeeping. Saved creds so we can re-login on resume
  // or after a backoff cycle. Held in memory only — they're already
  // in the keychain via TraccarApi for persistence across launches.
  String? _savedEmail;
  String? _savedPassword;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _reconnectInProgress = false;
  static const Duration _reconnectFirstDelay = Duration(seconds: 1);
  static const Duration _reconnectMaxDelay = Duration(seconds: 30);

  TraccarConnectionStatus _connectionStatus = TraccarConnectionStatus.disconnected;

  // Getters
  //
  // The map/list getters return VIEWS that external callers can read
  // but not mutate. Without this, screens could (and historically
  // did in earlier prototypes) reach in and modify provider state
  // directly, sidestepping notifyListeners() — leading to "the data
  // changed but the UI didn't rebuild" bugs that are painful to
  // diagnose. UnmodifiableMapView / UnmodifiableListView wrap the
  // underlying collection without copying, so this is cheap on every
  // read (vs `Map.unmodifiable` which would allocate per getter call).
  List<Device> get devices => UnmodifiableListView(_devices);
  Map<int, Position> get lastPositions => UnmodifiableMapView(_lastPositions);
  List<Geofence> get geofences => UnmodifiableListView(_geofences);
  Map<int, List<Position>> get positionHistory => UnmodifiableMapView(_positionHistory);
  List<TraccarEvent> get recentEvents => UnmodifiableListView(_recentEvents);
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TraccarConnectionStatus get connectionStatus => _connectionStatus;

  /// Initialize connection to Traccar
  Future<bool> connect(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _connectionStatus = TraccarConnectionStatus.connecting;
    notifyListeners();

    try {
      // Login to Traccar (Basic auth — used for HTTP REST calls).
      final success = await _api.login(email, password);

      if (success) {
        _isConnected = true;
        _savedEmail = email;
        _savedPassword = password;

        await _establishWebSocketSession(email: email, password: password);

        // Load initial devices and positions
        await refreshDevices();

        _isLoading = false;
        _connectionStatus = TraccarConnectionStatus.connected;
        _reconnectAttempts = 0;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Credenciales inválidas';
        _isLoading = false;
        _connectionStatus = TraccarConnectionStatus.disconnected;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      _isLoading = false;
      _connectionStatus = TraccarConnectionStatus.disconnected;
      notifyListeners();
      return false;
    }
  }

  /// Establish the JSESSIONID cookie + WebSocket + stream subscriptions.
  /// Extracted so connect() (first login) and the reconnect loop share
  /// one code path; without this, any future change to the session
  /// handshake has to be remembered in two places.
  Future<void> _establishWebSocketSession({
    required String email,
    required String password,
  }) async {
    // The WS upgrade requires a JSESSIONID cookie; the cookie may have
    // expired during the outage so we always re-establish before
    // reconnecting (see TraccarApi for the full diagnosis).
    final sessionCookie = await _api.establishSession(
      email: email,
      password: password,
    );
    if (sessionCookie == null) {
      // Don't fail the connect — Basic-auth REST still works, the user
      // just won't get real-time updates until the next reconnect.
      // ignore: avoid_print
      print('TraccarProvider: establishSession returned null; '
          'WebSocket will likely fail to upgrade.');
    }

    // Cancel any prior subscriptions before opening new ones — the
    // reconnect path can otherwise pile up duplicate listeners.
    await _positionSubscription?.cancel();
    await _eventSubscription?.cancel();
    await _statusSubscription?.cancel();

    await _ws.connect(sessionCookie: sessionCookie);

    _positionSubscription = _ws.positionStream.listen(_handlePositionUpdate);
    _eventSubscription = _ws.eventStream.listen(_handleEventUpdate);
    _statusSubscription = _ws.statusStream.listen(_handleWebSocketStatus);
  }

  /// React to WebSocket status changes emitted by the underlying
  /// TraccarWebSocket. We care specifically about disconnect/error
  /// events — those are the silent-failure modes that previously left
  /// the En vivo map showing a stale dot indefinitely.
  void _handleWebSocketStatus(String status) {
    if (status == 'connected') {
      _connectionStatus = TraccarConnectionStatus.connected;
      _reconnectAttempts = 0;
      notifyListeners();
      return;
    }
    if (status == 'disconnected' || status == 'error') {
      // Only schedule a reconnect if we previously had creds (i.e.
      // the user is signed into Traccar). A disconnect during logout
      // is expected and should not trigger reconnect.
      if (_savedEmail == null || _savedPassword == null) return;
      _connectionStatus = TraccarConnectionStatus.reconnecting;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  /// Schedule the next reconnect attempt with exponential backoff:
  /// 1, 2, 4, 8, 16, 30, 30, 30… seconds. Capped at 30s so the user
  /// doesn't wait minutes for a recovery after a long outage. The
  /// cap is also what AppLifecycleState.resumed bypasses (we always
  /// force an immediate attempt on resume).
  void _scheduleReconnect() {
    if (_reconnectInProgress) return;
    _reconnectTimer?.cancel();

    final attempt = _reconnectAttempts;
    final delaySeconds = (_reconnectFirstDelay.inSeconds << attempt)
        .clamp(_reconnectFirstDelay.inSeconds, _reconnectMaxDelay.inSeconds);
    final delay = Duration(seconds: delaySeconds);

    if (kDebugMode) {
      debugPrint(
        'TraccarProvider: scheduling reconnect attempt ${attempt + 1} in ${delay.inSeconds}s',
      );
    }
    _reconnectTimer = Timer(delay, _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    if (_reconnectInProgress) return;
    final email = _savedEmail;
    final password = _savedPassword;
    if (email == null || password == null) return;
    _reconnectInProgress = true;
    _reconnectAttempts++;
    try {
      // Re-login first in case the REST credentials lapsed during the
      // outage — login() returns quickly on still-valid sessions.
      final ok = await _api.login(email, password);
      if (!ok) {
        // Credentials no longer accepted (rare, but possible after a
        // server-side password rotation). Stop retrying — the user
        // will be prompted to sign in again on next launch.
        _connectionStatus = TraccarConnectionStatus.disconnected;
        notifyListeners();
        return;
      }
      await _establishWebSocketSession(email: email, password: password);
      // _establishWebSocketSession opens the socket synchronously; the
      // 'connected' status arrives on _statusSubscription which resets
      // _reconnectAttempts. No need to touch state here on success —
      // the listener will fire.
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TraccarProvider: reconnect attempt failed: $e');
      }
      // Schedule the next attempt with a longer backoff.
      _scheduleReconnect();
    } finally {
      _reconnectInProgress = false;
    }
  }

  /// Force an immediate reconnect attempt — called by main.dart's
  /// lifecycle observer on AppLifecycleState.resumed. iOS aggressively
  /// suspends the socket while the app is backgrounded; the
  /// suspension often doesn't surface as a 'disconnected' event until
  /// the next ping fails, which can take minutes. Forcing on resume
  /// bridges that gap.
  void handleAppResumed() {
    if (_savedEmail == null || _savedPassword == null) return;
    if (_connectionStatus == TraccarConnectionStatus.connected) {
      // Even if the socket says it's connected, force a probe by
      // re-establishing the session — iOS will silently say "open"
      // while the OS has actually torn it down.
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      unawaited(_attemptReconnect());
      return;
    }
    if (_connectionStatus == TraccarConnectionStatus.reconnecting) {
      // Drop the backoff timer and try immediately.
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      unawaited(_attemptReconnect());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      handleAppResumed();
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
          final position = await _api.getLastPosition(device.requireTraccarId());
          if (position != null) {
            _lastPositions[device.requireTraccarId()] = position;
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

      // Log into Traccar with the credentials just returned by the provisioning
      // API so that subsequent calls (refreshDevices, WebSocket, etc.) carry the
      // Basic auth header. Without this, every Traccar call returns 401.
      // Note: idempotent 200 responses do NOT return credentials; in that case
      // we fall back to whatever credentials the app already has stored.
      final creds = _provisioningApi.getLastProvisionedCredentials();
      if (creds != null && creds['email'] != null && creds['password'] != null) {
        await _api.login(creds['email'], creds['password']);
      }

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

  /// Create circular geofence and link it to a device.
  ///
  /// Returns the new geofence id on success, or null on failure.
  ///
  /// WKT format note: Traccar's CIRCLE expects
  ///   `CIRCLE (LAT LON, RADIUS_METERS)`
  /// — radius in METERS, comma between the longitude and radius. The
  /// previous version of this method converted to degrees and used a
  /// space; that produced geofences that visually rendered but never
  /// actually triggered geofenceEnter/geofenceExit events because the
  /// radius was off by ~111000×. Verified by walking the device out of
  /// a "100m" zone and getting no event. Now fixed.
  Future<int?> createCircularGeofence({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required int deviceId,
    Map<String, dynamic>? attributes,
  }) async {
    try {
      final area = 'CIRCLE ($latitude $longitude, $radiusMeters)';

      final geofence = await _api.createGeofence(
        name: name,
        area: area,
        attributes: attributes,
      );

      if (geofence == null) return null;

      final geofenceId = geofence['id'] as int;
      final linked = await _api.linkGeofenceToDevice(geofenceId, deviceId);
      if (!linked) {
        // Geofence exists in Traccar but isn't linked to the device. Not
        // strictly an error (admin can link manually) but worth logging.
        debugPrint(
            'Warning: created geofence $geofenceId but failed to link to device $deviceId');
      }
      return geofenceId;
    } catch (e) {
      _errorMessage = 'Error al crear zona: $e';
      notifyListeners();
      return null;
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
    // Stop any pending reconnect work BEFORE tearing down the
    // socket — otherwise the close event fires _handleWebSocketStatus
    // which schedules a new reconnect, which races with this method.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _savedEmail = null;
    _savedPassword = null;

    await _positionSubscription?.cancel();
    await _eventSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _ws.disconnect();
    await _api.logout();

    _isConnected = false;
    _connectionStatus = TraccarConnectionStatus.disconnected;
    _devices = [];
    _lastPositions = {};
    _positionHistory = {};
    _recentEvents = [];

    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disconnect();
    super.dispose();
  }
}
