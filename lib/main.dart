import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
// Petti is the global theme as of 2026-04-27. The legacy `utils/theme.dart`
// is no longer imported; it can be deleted once we confirm no straggler
// screens reference AppTheme directly. See utils/petti_theme.dart for the
// rationale and full token list.
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/traccar_provider.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'utils/app_navigator.dart';
import 'utils/petti_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register the FCM background message handler BEFORE runApp so it's
  // wired in time for messages that arrive during cold start. The handler
  // itself does minimal work today — the OS shows the notification, and
  // FCMService.initialize()'s getInitialMessage() takes over once the
  // app has booted.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const PetTrackApp());
}

class PetTrackApp extends StatefulWidget {
  const PetTrackApp({super.key});

  @override
  State<PetTrackApp> createState() => _PetTrackAppState();
}

class _PetTrackAppState extends State<PetTrackApp> {
  late final NotificationProvider _notificationProvider;
  final FCMService _fcm = FCMService();

  @override
  void initState() {
    super.initState();

    // Build the NotificationProvider eagerly so the FCM service can hand
    // it inbound messages (and so `bell badge` updates the moment a push
    // lands while the user is in the app).
    _notificationProvider = NotificationProvider()..initialize();

    // Defer FCM initialization to the first post-frame callback so the
    // navigator key is mounted before any cold-start tap tries to push a
    // route via getInitialMessage(). Without this guard, a user tapping
    // a notification from a terminated state could cause a navigate-
    // before-runApp race.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fcm.initialize(notificationProvider: _notificationProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TraccarProvider()),
        // Reuse the eagerly-constructed instance so FCM and the widget
        // tree share the same NotificationProvider state.
        ChangeNotifierProvider.value(value: _notificationProvider),
        // FCMService isn't a ChangeNotifier (no rebuild-driving state) but
        // we expose it via Provider so screens can call its methods —
        // specifically the Zona Segura wizard calls
        // requestPermissionAndRegister() after success, instead of
        // permission being prompted at app launch. See fcm_service.dart.
        Provider<FCMService>.value(value: _fcm),
      ],
      child: MaterialApp(
        title: 'PetTrack',
        theme: PettiTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        // These keys let FCM handlers (which run outside the widget tree)
        // navigate and show snackbars. See utils/app_navigator.dart.
        navigatorKey: AppNavigator.navigatorKey,
        scaffoldMessengerKey: AppNavigator.scaffoldMessengerKey,
        home: const SplashScreen(),
      ),
    );
  }
}
