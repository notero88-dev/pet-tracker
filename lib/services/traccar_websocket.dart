import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
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

  /// Connect to Traccar WebSocket.
  ///
  /// Traccar's `/api/socket` endpoint refuses the HTTP→WS upgrade unless
  /// the request carries a valid `JSESSIONID` cookie tied to a server-side
  /// session (Basic auth on the upgrade request is also rejected). Without
  /// the cookie, Jetty 12 silently returns HTTP 200 with an empty body
  /// instead of HTTP 101, and `WebSocketChannel.connect` throws
  /// "was not upgraded to websocket".
  ///
  /// Caller must obtain the cookie via [TraccarApi.establishSession] and
  /// pass it here. We use [IOWebSocketChannel.connect] (dart:io path) to
  /// attach the `Cookie` header — the cross-platform [WebSocketChannel.connect]
  /// doesn't support custom headers. iOS-only is fine for now; if we ever
  /// build for Flutter web, we'll need a different strategy (CORS +
  /// `withCredentials` on the WS handshake).
  Future<void> connect({String? sessionCookie}) async {
    if (_isConnected) {
      debugPrint('WebSocket already connected');
      return;
    }

    try {
      // Hand-roll the underlying WebSocket so we can inject the Cookie
      // header on the upgrade request. IOWebSocketChannel.connect's
      // `headers` parameter is the documented path for this.
      final socket = await io.WebSocket.connect(
        AppConstants.traccarWebSocketUrl,
        headers: <String, dynamic>{
          if (sessionCookie != null) 'Cookie': 'JSESSIONID=$sessionCookie',
        },
      );
      _channel = IOWebSocketChannel(socket);

      _isConnected = true;
      _statusController?.add('connected');

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleClose,
      );

      debugPrint('WebSocket connected to Traccar (cookie: '
          '${sessionCookie != null ? "JSESSIONID=${sessionCookie.length} chars" : "NONE — will fail"})');
    } catch (e) {
      _isConnected = false;
      _statusController?.add('error');
      debugPrint('WebSocket connection error: $e');
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
        debugPrint('Device update: ${data['devices']}');
        _statusController?.add('device_update');
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  /// Handle WebSocket error
  void _handleError(error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    _statusController?.add('error');
  }

  /// Handle WebSocket close
  void _handleClose() {
    debugPrint('WebSocket connection closed');
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
