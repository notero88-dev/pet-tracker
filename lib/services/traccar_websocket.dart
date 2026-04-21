import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/constants.dart';
import '../models/position.dart';
import '../models/traccar_event.dart';

/// WebSocket client for Traccar real-time updates
class TraccarWebSocket {
  WebSocketChannel? _channel;
  StreamController<Position>? _positionController;
  StreamController<TraccarEvent>? _eventController;
  StreamController<String>? _statusController;
  
  bool _isConnected = false;
  String? _sessionCookie;
  
  /// Stream of position updates
  Stream<Position> get positionStream {
    _positionController ??= StreamController<Position>.broadcast();
    return _positionController!.stream;
  }
  
  /// Stream of events (geofence, alarms, etc.)
  Stream<TraccarEvent> get eventStream {
    _eventController ??= StreamController<TraccarEvent>.broadcast();
    return _eventController!.stream;
  }
  
  /// Stream of connection status changes
  Stream<String> get statusStream {
    _statusController ??= StreamController<String>.broadcast();
    return _statusController!.stream;
  }
  
  bool get isConnected => _isConnected;

  /// Connect to Traccar WebSocket
  /// 
  /// Requires session cookie from HTTP login to Traccar
  /// (Usually we don't expose Traccar directly to app, but this is for real-time updates)
  /// 
  /// For MVP: We'll use Firebase UID to authenticate via backend proxy
  Future<void> connect({String? sessionCookie}) async {
    if (_isConnected) {
      print('WebSocket already connected');
      return;
    }

    _sessionCookie = sessionCookie;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConstants.traccarWebSocketUrl),
      );

      _isConnected = true;
      _statusController?.add('connected');

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleClose,
      );

      print('WebSocket connected to Traccar');
    } catch (e) {
      _isConnected = false;
      _statusController?.add('error');
      print('WebSocket connection error: $e');
      rethrow;
    }
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      
      // Traccar WebSocket sends JSON with type field
      if (data['positions'] != null) {
        // Position update
        final positions = data['positions'] as List;
        for (var posJson in positions) {
          final position = Position.fromJson(posJson);
          _positionController?.add(position);
        }
      }
      
      if (data['events'] != null) {
        // Event update
        final events = data['events'] as List;
        for (var eventJson in events) {
          final event = TraccarEvent.fromJson(eventJson);
          _eventController?.add(event);
        }
      }
      
      if (data['devices'] != null) {
        // Device update (status change)
        print('Device update: ${data['devices']}');
        _statusController?.add('device_update');
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  /// Handle WebSocket error
  void _handleError(error) {
    print('WebSocket error: $error');
    _isConnected = false;
    _statusController?.add('error');
  }

  /// Handle WebSocket close
  void _handleClose() {
    print('WebSocket connection closed');
    _isConnected = false;
    _statusController?.add('disconnected');
  }

  /// Disconnect WebSocket
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _isConnected = false;
    _statusController?.add('disconnected');
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _positionController?.close();
    _eventController?.close();
    _statusController?.close();
  }
}
