// Firebase Cloud Messaging service.
//
// Owns three call paths into Flutter for a single push notification:
//
//   1. FOREGROUND (`FirebaseMessaging.onMessage`)
//      App is open and the user is actively in it. iOS suppresses the
//      OS banner in this state by design, so we render our own:
//      a Petti slide-down via `PettiAlertOverlay.show(...)`.
//      The notification is also persisted into NotificationProvider so
//      the bell icon's badge count and the Notifications screen update.
//
//   2. BACKGROUND TAP (`FirebaseMessaging.onMessageOpenedApp`)
//      App is in the background and the user taps the OS notification.
//      Android/iOS bring the app to the foreground, then this fires.
//      Push the AlertDetailScreen via the global navigator key.
//
//   3. COLD START (`FirebaseMessaging.getInitialMessage`)
//      App was terminated when the user tapped the OS notification.
//      The OS launches the app and we get the message via getInitialMessage.
//      Same handling as #2 but deferred until after auth + initial nav.
//
// All three paths funnel through `_buildNotificationFromMessage()` to
// produce a typed `AppNotification` from the RemoteMessage's data fields.
// The push-service stringifies all fields, so we parse on demand here.
//
// This service is owned by `main.dart` — it's instantiated once and
// `initialize()` runs after Firebase.initializeApp + the providers exist
// in the widget tree. AppNavigator.navigatorKey must be plugged into
// MaterialApp before any navigation calls fire.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../providers/notification_provider.dart';
import '../screens/alerts/alert_detail_screen.dart';
import '../utils/app_navigator.dart';
import '../widgets/petti/petti_alert_banner.dart';
import 'firestore_service.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _firestore = FirestoreService();

  /// Set by main.dart after providers are mounted, so handlers can write
  /// into the notification list without needing a BuildContext. Non-null
  /// after `initialize()` returns.
  NotificationProvider? notificationProvider;

  /// Initialize FCM. Returns once permissions are settled and handlers
  /// are wired. Safe to call multiple times — idempotent.
  Future<void> initialize({NotificationProvider? notificationProvider}) async {
    this.notificationProvider = notificationProvider;

    // Web has no FCM in this app — needs a service worker + VAPID key,
    // neither of which is set up. Production targets iOS/Android only.
    if (kIsWeb) {
      debugPrint(
          'FCM: skipping initialization on web (no service worker configured)');
      return;
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM: User granted permission');

        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('FCM Token: $token');
          await _firestore.saveFcmToken(token);
        }
        _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('FCM Token refreshed: $newToken');
          _firestore.saveFcmToken(newToken);
        });
      } else {
        debugPrint('FCM: User declined or has not accepted permission');
      }

      _registerHandlers();

      // Cold-start: the user tapped a notification while the app was
      // terminated. Handle deferred so we don't try to navigate before
      // the navigator is mounted.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleTap(initial);
        });
      }
    } catch (e) {
      debugPrint('FCM Error: $e');
    }
  }

  /// Wire up foreground + background-tap handlers. Both call into the
  /// shared message-to-AppNotification converter.
  void _registerHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
  }

  /// FCM arrived while app is in foreground. Persist + show in-app banner.
  void _handleForeground(RemoteMessage message) {
    debugPrint('FCM foreground: ${message.messageId}');
    final notification = _buildNotificationFromMessage(message);
    if (notification == null) return;

    // Persist immediately so the bell badge updates and the Notifications
    // screen reflects it on next open.
    notificationProvider?.addNotification(notification);

    // Show the Petti banner if the navigator is mounted (it should always
    // be by this point, since onMessage only fires when the app is alive).
    final overlayState =
        AppNavigator.navigatorKey.currentState?.overlay;
    if (overlayState != null) {
      PettiAlertOverlay.showOnOverlay(
        overlay: overlayState,
        notification: notification,
        onTap: () => _navigateToDetail(notification),
      );
    }
  }

  /// User tapped an OS-level FCM notification (background or terminated).
  /// Push the AlertDetailScreen.
  void _handleTap(RemoteMessage message) {
    debugPrint('FCM tap: ${message.messageId}');
    final notification = _buildNotificationFromMessage(message);
    if (notification == null) return;

    // Persist if not already (background handler doesn't see the message
    // unless we wire a top-level firebaseMessagingBackgroundHandler too;
    // for now save here on tap so the list stays consistent).
    notificationProvider?.addNotification(notification);

    _navigateToDetail(notification);
  }

  /// Push AlertDetailScreen via the global navigator key. Safe to call
  /// from non-context callbacks. No-op if the navigator isn't mounted yet
  /// (e.g. cold-start fired this before runApp completed — initialize()
  /// guards that case with addPostFrameCallback).
  void _navigateToDetail(AppNotification notification) {
    if (!AppNavigator.isMounted) return;
    AppNavigator.navigator.push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(notification: notification),
      ),
    );
  }

  /// Convert an FCM RemoteMessage to our typed AppNotification.
  ///
  /// The push-service always populates `data.alertType` and the standard
  /// fields documented in pettrack-backend/push-service/src/utils/templates.js.
  /// This converter is forgiving: missing fields produce null/empty values
  /// rather than throwing, so a malformed message still surfaces in the
  /// list rather than silently dropping.
  AppNotification? _buildNotificationFromMessage(RemoteMessage message) {
    try {
      final data = message.data;
      final notif = message.notification;

      // Title/body: prefer the OS-notification fields when present, fall
      // back to the data payload (some FCM senders only set data — e.g.
      // silent pushes that we render entirely via our own UI).
      final title =
          notif?.title ?? (data['title'] as String?) ?? 'Alerta';
      final body =
          notif?.body ?? (data['body'] as String?) ?? '';

      final alertType = (data['alertType'] as String?) ??
          (data['type'] as String?) ??
          'general';

      // Prefer the server-side alert id (data.alertId) so persisting +
      // marking-read can be deduplicated across channels. Fall back to the
      // FCM messageId for unknown payloads.
      final id = (data['alertId'] as String?)?.isNotEmpty == true
          ? data['alertId'] as String
          : message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

      final timestampStr = data['timestamp'] as String?;
      final timestamp = timestampStr != null
          ? (DateTime.tryParse(timestampStr) ?? DateTime.now())
          : DateTime.now();

      return AppNotification(
        id: id,
        title: title,
        body: body,
        type: NotificationType.fromString(alertType),
        timestamp: timestamp,
        isRead: false,
        data: Map<String, dynamic>.from(data),
        deviceId: data['deviceId'] as String?,
      );
    } catch (e) {
      debugPrint('FCM: failed to build notification from message: $e');
      return null;
    }
  }

  /// Get current FCM token. Used at signup to register the user.
  Future<String?> getToken() => _messaging.getToken();

  /// Delete FCM token (on logout).
  Future<void> deleteToken() => _messaging.deleteToken();
}

/// Top-level background message handler.
///
/// FCM requires a top-level / static function for messages that arrive
/// while the app is fully terminated. We don't do meaningful work here
/// today — the OS shows the notification, and once the user taps and
/// the app launches, `getInitialMessage()` (called from initialize)
/// handles routing.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}
