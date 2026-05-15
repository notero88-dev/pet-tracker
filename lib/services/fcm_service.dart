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

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../providers/notification_provider.dart';
import '../screens/alerts/alert_detail_screen.dart';
import '../utils/app_navigator.dart';
import '../widgets/petti/petti_alert_banner.dart';
import 'device_command_events.dart';
import 'firestore_service.dart';
import 'provisioning_api.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _firestore = FirestoreService();

  /// Set by main.dart after providers are mounted, so handlers can write
  /// into the notification list without needing a BuildContext. Non-null
  /// after `initialize()` returns.
  NotificationProvider? notificationProvider;

  /// Token-refresh subscription. Created lazily once the user has granted
  /// permission so we don't subscribe (and quietly fail) before we have a
  /// usable token.
  StreamSubscription<String>? _tokenRefreshSub;

  /// Wire up FCM message handlers + cold-start routing. Does NOT prompt the
  /// user for notification permission — that's deferred to
  /// [requestPermissionAndRegister], called from the Zona Segura wizard's
  /// success step where the user has narrative context for what they're
  /// allowing.
  ///
  /// Why split: requesting permission at app launch means a brand-new user
  /// sees the iOS dialog before they understand what alerts they'll get.
  /// Acceptance rates roughly double when the prompt fires immediately
  /// after the user has just configured "alert me when my pet leaves home".
  /// We still need handlers wired at boot so any already-authorized user
  /// receives messages from the first frame; only the prompt is deferred.
  ///
  /// Safe to call multiple times — idempotent.
  Future<void> initialize({NotificationProvider? notificationProvider}) async {
    this.notificationProvider = notificationProvider;

    if (kIsWeb) {
      debugPrint(
          'FCM: skipping initialization on web (no service worker configured)');
      return;
    }

    try {
      _registerHandlers();

      // Re-bind the token if the user previously granted permission.
      // getToken() returns null on iOS without permission, so this is a
      // no-op for fresh installs — they'll get a token via
      // requestPermissionAndRegister later.
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _bindToken();
      } else {
        debugPrint(
            'FCM: permission not yet requested or denied — deferring token registration. '
            'Call FCMService.requestPermissionAndRegister() after Zona Segura succeeds.');
      }

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
      debugPrint('FCM Error during initialize: $e');
    }
  }

  /// Prompt the user for notification permission and register the FCM
  /// token. Call this from the Zona Segura wizard's success step (or
  /// anywhere else the user has just opted into a feature that needs
  /// alerts).
  ///
  /// Returns the resulting [AuthorizationStatus] so the caller can show
  /// follow-up UI (e.g. "Activa las alertas en ajustes" if denied).
  ///
  /// Idempotent — if the user has already granted permission this just
  /// re-registers the token. If they denied, a second call re-prompts on
  /// Android but iOS will silently return the existing denial; the user
  /// has to re-enable in iOS Settings, which the app should surface in a
  /// follow-up banner.
  Future<AuthorizationStatus> requestPermissionAndRegister() async {
    if (kIsWeb) {
      return AuthorizationStatus.notDetermined;
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint(
            'FCM: User granted permission (status=${settings.authorizationStatus})');
        await _bindToken();
      } else {
        debugPrint(
            'FCM: User declined permission (status=${settings.authorizationStatus})');
      }
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('FCM Error during requestPermissionAndRegister: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Get the current FCM token (if available) and persist it to BOTH
  /// Firestore (read by the app itself, e.g. settings) AND the
  /// provisioning-api postgres (read by the push-service when it fans
  /// out geofenceExit / alarm events to FCM).
  ///
  /// Why both:
  ///   - Firestore: the app reads its own user doc for diagnostics
  ///     and may surface token registration state in Settings.
  ///   - Postgres: push-service (`notificationService.js` →
  ///     `database.getCustomerByDeviceId`) looks up the token there.
  ///     Without this bridge no notifications can be sent — even with
  ///     a Traccar geofenceExit firing correctly.
  ///
  /// Both writes are best-effort; one failing doesn't block the other.
  Future<void> _bindToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await _persistToken(token);
    }
    _tokenRefreshSub ??= _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      _persistToken(newToken);
    });
  }

  /// Write the FCM token to Firestore + provisioning-api in parallel.
  /// Either failing is logged but doesn't throw — the next token
  /// refresh will retry.
  Future<void> _persistToken(String token) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    await Future.wait([
      _firestore.saveFcmToken(token).catchError((e) {
        debugPrint('FCM: Firestore saveFcmToken failed: $e');
      }),
      if (email != null) _postTokenToProvisioningApi(email, token),
    ]);
  }

  /// Register the token with provisioning-api so push-service can
  /// look it up in postgres. Delegated to ProvisioningApi so the API
  /// key + base URL stay in one place. Best-effort; failure logged.
  Future<void> _postTokenToProvisioningApi(String email, String token) async {
    final ok = await ProvisioningApi()
        .registerFcmToken(email: email, token: token);
    debugPrint(ok
        ? 'FCM: token registered with provisioning-api'
        : 'FCM: provisioning-api registration failed (best-effort, will retry on next refresh)');
  }

  /// Current notification permission status. Use this to gate UI like
  /// "tap here to enable alerts in settings" banners.
  Future<AuthorizationStatus> get permissionStatus async {
    if (kIsWeb) return AuthorizationStatus.notDetermined;
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
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

    // Silent system signals (data-only, no notification block, type marks
    // them as internal). These don't go to the alert list or banner —
    // they emit on a side-channel for whatever screen is interested.
    // Shipped 2026-05-15 alongside the 202/queued + completion-webhook
    // chain that fixes the "En vivo Bad file descriptor" failure.
    if (_isSystemSignal(message)) {
      _routeSystemSignal(message);
      return;
    }

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

    // System signals shouldn't ever surface a tappable notification (we
    // send them as data-only with no alert block), but if iOS somehow
    // surfaces one anyway, route it through the signal handler so we
    // at least update internal state instead of falling into the
    // AlertDetailScreen with a meaningless payload.
    if (_isSystemSignal(message)) {
      _routeSystemSignal(message);
      return;
    }

    final notification = _buildNotificationFromMessage(message);
    if (notification == null) return;

    // Persist if not already (background handler doesn't see the message
    // unless we wire a top-level firebaseMessagingBackgroundHandler too;
    // for now save here on tap so the list stays consistent).
    notificationProvider?.addNotification(notification);

    _navigateToDetail(notification);
  }

  /// Is this RemoteMessage one of our internal system-signal types
  /// (currently just `command_completed`)? System signals get routed
  /// out-of-band via [DeviceCommandEvents] rather than into the user-
  /// facing notification list.
  bool _isSystemSignal(RemoteMessage message) {
    final t = message.data['type'] as String?;
    return t == 'command_completed';
  }

  /// Convert a `command_completed` data-only push into a typed
  /// CommandCompletedEvent and emit it. Whatever screen is interested
  /// (DeviceDetailScreen's live-mode button today) subscribes to
  /// DeviceCommandEvents.instance.stream and reacts.
  void _routeSystemSignal(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    if (type != 'command_completed') {
      debugPrint('FCM: unknown system signal type=$type, ignoring');
      return;
    }
    final imei = (data['imei'] as String?) ?? '';
    final command = (data['command'] as String?) ?? '';
    final status = (data['status'] as String?) ?? '';
    if (imei.isEmpty || command.isEmpty || status.isEmpty) {
      debugPrint('FCM: command_completed missing imei/command/status, dropping');
      return;
    }
    final queueIdStr = (data['queueId'] as String?) ?? '';
    final queueId = int.tryParse(queueIdStr);
    final payload =
        (data['payload'] as String?)?.isNotEmpty == true
            ? data['payload'] as String?
            : null;
    final firedAtStr = (data['firedAt'] as String?) ?? '';
    final firedAt = DateTime.tryParse(firedAtStr) ?? DateTime.now();
    final petName = (data['petName'] as String?) ?? '';
    debugPrint(
      'FCM command_completed: imei=$imei command=$command '
      'queueId=$queueId status=$status',
    );
    DeviceCommandEvents.instance.emit(CommandCompletedEvent(
      imei: imei,
      command: command,
      queueId: queueId,
      status: status,
      payload: payload,
      firedAt: firedAt,
      petName: petName,
    ));
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
