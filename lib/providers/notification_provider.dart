import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/notification.dart';

/// Provider for app notifications
class NotificationProvider with ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  // Notification settings
  NotificationSettings _settings = NotificationSettings();

  // Getters
  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => unreadNotifications.length;
  bool get isLoading => _isLoading;
  NotificationSettings get settings => _settings;

  /// Initialize and load notifications from storage
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _loadNotifications();
    await _loadSettings();

    _isLoading = false;
    notifyListeners();
  }

  /// Load notifications from SharedPreferences
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString('notifications');
      
      if (notificationsJson != null) {
        final List<dynamic> decoded = jsonDecode(notificationsJson);
        _notifications = decoded
            .map((json) => AppNotification.fromJson(json))
            .toList();
        
        // Sort by timestamp (newest first)
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  /// Save notifications to SharedPreferences
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = jsonEncode(
        _notifications.map((n) => n.toJson()).toList(),
      );
      await prefs.setString('notifications', notificationsJson);
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  /// Load settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('notification_settings');
      
      if (settingsJson != null) {
        _settings = NotificationSettings.fromJson(jsonDecode(settingsJson));
      }
    } catch (e) {
      print('Error loading notification settings: $e');
    }
  }

  /// Save settings
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'notification_settings',
        jsonEncode(_settings.toJson()),
      );
    } catch (e) {
      print('Error saving notification settings: $e');
    }
  }

  /// Add new notification
  Future<void> addNotification(AppNotification notification) async {
    // Check if notification type is enabled
    if (!_settings.isTypeEnabled(notification.type)) {
      return;
    }

    // Check Do Not Disturb
    if (_settings.isDndActive()) {
      // Only allow high priority during DND
      if (notification.priority < 2) {
        return;
      }
    }

    _notifications.insert(0, notification);
    
    // Keep only last 100 notifications
    if (_notifications.length > 100) {
      _notifications = _notifications.take(100).toList();
    }

    await _saveNotifications();
    notifyListeners();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      notifyListeners();
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _saveNotifications();
    notifyListeners();
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    notifyListeners();
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }

  /// Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Update settings
  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    notifyListeners();
  }
}

/// Notification settings model
class NotificationSettings {
  final bool geofenceEnterEnabled;
  final bool geofenceExitEnabled;
  final bool batteryLowEnabled;
  final bool deviceOfflineEnabled;
  final bool deviceOnlineEnabled;
  final bool speedAlertEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool dndEnabled;
  final TimeOfDay? dndStart;
  final TimeOfDay? dndEnd;
  final Set<int> dndDays; // 1=Monday, 7=Sunday

  NotificationSettings({
    this.geofenceEnterEnabled = true,
    this.geofenceExitEnabled = true,
    this.batteryLowEnabled = true,
    this.deviceOfflineEnabled = true,
    this.deviceOnlineEnabled = false,
    this.speedAlertEnabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.dndEnabled = false,
    this.dndStart,
    this.dndEnd,
    Set<int>? dndDays,
  }) : dndDays = dndDays ?? {1, 2, 3, 4, 5, 6, 7}; // All days by default

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      geofenceEnterEnabled: json['geofenceEnterEnabled'] as bool? ?? true,
      geofenceExitEnabled: json['geofenceExitEnabled'] as bool? ?? true,
      batteryLowEnabled: json['batteryLowEnabled'] as bool? ?? true,
      deviceOfflineEnabled: json['deviceOfflineEnabled'] as bool? ?? true,
      deviceOnlineEnabled: json['deviceOnlineEnabled'] as bool? ?? false,
      speedAlertEnabled: json['speedAlertEnabled'] as bool? ?? false,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      dndEnabled: json['dndEnabled'] as bool? ?? false,
      dndStart: json['dndStart'] != null
          ? _timeFromString(json['dndStart'])
          : null,
      dndEnd: json['dndEnd'] != null
          ? _timeFromString(json['dndEnd'])
          : null,
      dndDays: json['dndDays'] != null
          ? Set<int>.from(json['dndDays'])
          : {1, 2, 3, 4, 5, 6, 7},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'geofenceEnterEnabled': geofenceEnterEnabled,
      'geofenceExitEnabled': geofenceExitEnabled,
      'batteryLowEnabled': batteryLowEnabled,
      'deviceOfflineEnabled': deviceOfflineEnabled,
      'deviceOnlineEnabled': deviceOnlineEnabled,
      'speedAlertEnabled': speedAlertEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'dndEnabled': dndEnabled,
      'dndStart': dndStart != null ? _timeToString(dndStart!) : null,
      'dndEnd': dndEnd != null ? _timeToString(dndEnd!) : null,
      'dndDays': dndDays.toList(),
    };
  }

  static TimeOfDay _timeFromString(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Check if notification type is enabled
  bool isTypeEnabled(NotificationType type) {
    switch (type) {
      case NotificationType.geofenceEnter:
        return geofenceEnterEnabled;
      case NotificationType.geofenceExit:
        return geofenceExitEnabled;
      case NotificationType.batteryLow:
        return batteryLowEnabled;
      case NotificationType.deviceOffline:
        return deviceOfflineEnabled;
      case NotificationType.deviceOnline:
        return deviceOnlineEnabled;
      case NotificationType.speedAlert:
        return speedAlertEnabled;
      default:
        return true;
    }
  }

  /// Check if currently in Do Not Disturb period
  bool isDndActive() {
    if (!dndEnabled || dndStart == null || dndEnd == null) {
      return false;
    }

    final now = DateTime.now();
    final currentDay = now.weekday; // 1=Monday, 7=Sunday

    // Check if current day is in DND days
    if (!dndDays.contains(currentDay)) {
      return false;
    }

    final currentTime = TimeOfDay.fromDateTime(now);
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    final startMinutes = dndStart!.hour * 60 + dndStart!.minute;
    final endMinutes = dndEnd!.hour * 60 + dndEnd!.minute;

    // Handle overnight DND (e.g., 22:00 - 07:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }

  /// Copy with updated fields
  NotificationSettings copyWith({
    bool? geofenceEnterEnabled,
    bool? geofenceExitEnabled,
    bool? batteryLowEnabled,
    bool? deviceOfflineEnabled,
    bool? deviceOnlineEnabled,
    bool? speedAlertEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? dndEnabled,
    TimeOfDay? dndStart,
    TimeOfDay? dndEnd,
    Set<int>? dndDays,
  }) {
    return NotificationSettings(
      geofenceEnterEnabled: geofenceEnterEnabled ?? this.geofenceEnterEnabled,
      geofenceExitEnabled: geofenceExitEnabled ?? this.geofenceExitEnabled,
      batteryLowEnabled: batteryLowEnabled ?? this.batteryLowEnabled,
      deviceOfflineEnabled: deviceOfflineEnabled ?? this.deviceOfflineEnabled,
      deviceOnlineEnabled: deviceOnlineEnabled ?? this.deviceOnlineEnabled,
      speedAlertEnabled: speedAlertEnabled ?? this.speedAlertEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      dndStart: dndStart ?? this.dndStart,
      dndEnd: dndEnd ?? this.dndEnd,
      dndDays: dndDays ?? this.dndDays,
    );
  }
}
