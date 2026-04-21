import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

/// Firebase Cloud Messaging service for push notifications
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _firestore = FirestoreService();

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request permission (iOS)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM: User granted permission');
        
        // Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          debugPrint('FCM Token: $token');
          
          // Save token to Firestore
          await _firestore.saveFcmToken(token);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('FCM Token refreshed: $newToken');
          _firestore.saveFcmToken(newToken);
        });
      } else {
        debugPrint('FCM: User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint('FCM Error: $e');
    }
  }

  /// Handle foreground messages
  void setupForegroundHandler(Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  /// Handle background message tap (when app is in background/terminated)
  void setupBackgroundHandler(Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Delete FCM token (on logout)
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
  }
}

/// Top-level function for handling background messages
/// Required by Firebase Messaging for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  // Handle the background message (e.g., show local notification)
}
