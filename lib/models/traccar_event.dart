/// Traccar event (geofence, alarm, etc.)
class TraccarEvent {
  final int id;
  final int deviceId;
  final String type; // geofenceEnter, geofenceExit, alarm, deviceOnline, deviceOffline
  final DateTime eventTime;
  final int? geofenceId;
  final int? positionId;
  final Map<String, dynamic>? attributes;

  TraccarEvent({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.eventTime,
    this.geofenceId,
    this.positionId,
    this.attributes,
  });

  factory TraccarEvent.fromJson(Map<String, dynamic> json) {
    return TraccarEvent(
      id: json['id'] as int,
      deviceId: json['deviceId'] as int,
      type: json['type'] as String,
      eventTime: DateTime.parse(json['eventTime'] as String),
      geofenceId: json['geofenceId'] as int?,
      positionId: json['positionId'] as int?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'type': type,
      'eventTime': eventTime.toIso8601String(),
      'geofenceId': geofenceId,
      'positionId': positionId,
      'attributes': attributes,
    };
  }

  /// User-friendly event title in Spanish
  String get title {
    switch (type) {
      case 'geofenceEnter':
        return 'Zona segura';
      case 'geofenceExit':
        return '¡Fuera de zona!';
      case 'alarm':
        return 'Alarma';
      case 'deviceOnline':
        return 'Dispositivo conectado';
      case 'deviceOffline':
        return 'Dispositivo desconectado';
      case 'deviceMoving':
        return 'En movimiento';
      case 'deviceStopped':
        return 'Detenido';
      default:
        return 'Evento';
    }
  }

  /// User-friendly event message in Spanish
  String get message {
    switch (type) {
      case 'geofenceEnter':
        return 'Tu mascota entró a la zona segura';
      case 'geofenceExit':
        return 'Tu mascota salió de la zona segura';
      case 'alarm':
        return 'Se activó una alarma en el dispositivo';
      case 'deviceOnline':
        return 'El dispositivo GPS se conectó';
      case 'deviceOffline':
        return 'El dispositivo GPS se desconectó';
      case 'deviceMoving':
        return 'Tu mascota comenzó a moverse';
      case 'deviceStopped':
        return 'Tu mascota se detuvo';
      default:
        return 'Evento del dispositivo';
    }
  }

  /// Priority level for notifications
  int get priority {
    switch (type) {
      case 'geofenceExit':
      case 'alarm':
        return 2; // High
      case 'geofenceEnter':
      case 'deviceOffline':
        return 1; // Medium
      default:
        return 0; // Low
    }
  }

  /// Should send push notification
  bool get shouldNotify {
    return priority >= 1; // Medium or high priority
  }
}
