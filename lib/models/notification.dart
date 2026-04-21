import 'package:flutter/material.dart';

/// App notification model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data; // Extra payload data
  final String? deviceId;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
    this.deviceId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.fromString(json['type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
      deviceId: json['deviceId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.value,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'data': data,
      'deviceId': deviceId,
    };
  }

  /// Create copy with updated fields
  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      data: data,
      deviceId: deviceId,
    );
  }

  /// Icon for notification type
  IconData get icon {
    switch (type) {
      case NotificationType.geofenceEnter:
        return Icons.home;
      case NotificationType.geofenceExit:
        return Icons.warning;
      case NotificationType.batteryLow:
        return Icons.battery_alert;
      case NotificationType.deviceOffline:
        return Icons.signal_wifi_off;
      case NotificationType.deviceOnline:
        return Icons.wifi;
      case NotificationType.speedAlert:
        return Icons.speed;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  /// Color for notification type
  Color get color {
    switch (type) {
      case NotificationType.geofenceEnter:
        return Colors.green;
      case NotificationType.geofenceExit:
        return Colors.red;
      case NotificationType.batteryLow:
        return Colors.orange;
      case NotificationType.deviceOffline:
        return Colors.grey;
      case NotificationType.deviceOnline:
        return Colors.green;
      case NotificationType.speedAlert:
        return Colors.orange;
      case NotificationType.general:
        return Colors.blue;
    }
  }

  /// Priority level
  int get priority {
    switch (type) {
      case NotificationType.geofenceExit:
      case NotificationType.batteryLow:
        return 2; // High
      case NotificationType.deviceOffline:
      case NotificationType.speedAlert:
        return 1; // Medium
      default:
        return 0; // Low
    }
  }
}

enum NotificationType {
  geofenceEnter('geofence_enter'),
  geofenceExit('geofence_exit'),
  batteryLow('battery_low'),
  deviceOffline('device_offline'),
  deviceOnline('device_online'),
  speedAlert('speed_alert'),
  general('general');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    switch (value) {
      case 'geofence_enter':
      case 'geofenceEnter':
        return NotificationType.geofenceEnter;
      case 'geofence_exit':
      case 'geofenceExit':
        return NotificationType.geofenceExit;
      case 'battery_low':
      case 'batteryLow':
        return NotificationType.batteryLow;
      case 'device_offline':
      case 'deviceOffline':
        return NotificationType.deviceOffline;
      case 'device_online':
      case 'deviceOnline':
        return NotificationType.deviceOnline;
      case 'speed_alert':
      case 'speedAlert':
        return NotificationType.speedAlert;
      default:
        return NotificationType.general;
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.geofenceEnter:
        return 'Zona Segura';
      case NotificationType.geofenceExit:
        return 'Fuera de Zona';
      case NotificationType.batteryLow:
        return 'Batería Baja';
      case NotificationType.deviceOffline:
        return 'Desconectado';
      case NotificationType.deviceOnline:
        return 'Conectado';
      case NotificationType.speedAlert:
        return 'Velocidad';
      case NotificationType.general:
        return 'General';
    }
  }
}
