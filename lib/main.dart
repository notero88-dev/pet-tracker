import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
// Petti is the global theme as of 2026-04-27. The legacy `utils/theme.dart`
// is no longer imported; it can be deleted once we confirm no straggler
// screens reference AppTheme directly. See utils/petti_theme.dart for the
// rationale and full token list.
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/traccar_provider.dart';
import 'screens/splash_screen.dart';
import 'services/app_event_service.dart';
import 'services/fcm_service.dart';
import 'utils/app_navigator.dart';
import 'utils/petti_theme.dart';

// 2026-05-28: removed _DropletSelfSignedOverrides + HttpOverrides.global.
// The override previously trusted self-signed certs for raw IP
// 64.23.156.25 in ALL builds (a kDebugMode gate had been deliberately
// stripped on 2026-05-06 to keep dogfooding builds working). It is no
// longer needed: the app talks to https://api.mybesti.co exclusively,
// which serves a valid Let's Encrypt certificate, so the standard
// HttpClient path validates cleanly. Leaving the override in release
// builds would have been an MITM hole on untrusted Wi-Fi and an ATS
// rejection risk during App Review. If a raw-IP fallback is ever
// needed again, re-add the override gated strictly on `kDebugMode`.

void main() async {
  // The whole startup runs inside runZonedGuarded so any uncaught async
  // error anywhere in the app flows to Crashlytics. The four handlers
  // wired below cover the four error surfaces Flutter exposes:
  //
  //   1. FlutterError.onError              — synchronous framework errors
  //                                          (widget build, paint, layout)
  //   2. PlatformDispatcher.instance.onError — uncaught engine errors
  //                                          (asyncs that bubble past
  //                                          the Flutter framework)
  //   3. Isolate error listener            — errors in background isolates
  //                                          (compute(), spawned isolates)
  //   4. runZonedGuarded outer catch       — async errors in dart:io,
  //                                          timers, etc. that bypass
  //                                          the dispatcher
  //
  // Crashlytics collection is disabled in debug builds to keep the
  // Firebase Console clean of dev-time crashes (Flutter hot-reload
  // intentionally crashes-and-restarts a lot).
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Crashlytics — disable in debug so hot-reload crashes don't spam
    // the Firebase Console. Release builds collect.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );

    // Surface (1): synchronous Flutter framework errors. recordFlutterError
    // marks them as fatal=false (they don't crash the app but should be
    // reported); recordFlutterFatalError would mark them fatal=true.
    // For production we want all of them visible — non-fatal still shows
    // in the Crashlytics dashboard with the same stack trace + breadcrumbs.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };

    // Surface (2): uncaught engine-level async errors.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Surface (3): background isolate errors. RawReceivePort routes them
    // to a closure that hands them to Crashlytics. The cast to List is
    // because Isolate.errors yields [error, stack] pairs as dynamic.
    Isolate.current.addErrorListener(
      RawReceivePort((dynamic pair) async {
        final list = pair as List<dynamic>;
        await FirebaseCrashlytics.instance.recordError(
          list.first,
          list.last is StackTrace ? list.last as StackTrace : null,
          fatal: true,
        );
      }).sendPort,
    );

    // Register the FCM background message handler BEFORE runApp so it's
    // wired in time for messages that arrive during cold start. The handler
    // itself does minimal work today — the OS shows the notification, and
    // FCMService.initialize()'s getInitialMessage() takes over once the
    // app has booted.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    runApp(const PetTrackApp());
  }, (error, stack) {
    // Surface (4): anything else uncaught inside the zone — async errors
    // outside the dispatcher (dart:io exceptions in timers, compute()
    // failures, etc.).
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class PetTrackApp extends StatefulWidget {
  const PetTrackApp({super.key});

  @override
  State<PetTrackApp> createState() => _PetTrackAppState();
}

class _PetTrackAppState extends State<PetTrackApp> with WidgetsBindingObserver {
  late final NotificationProvider _notificationProvider;
  // SubscriptionProvider is hoisted to a field (eager construction
  // + ChangeNotifierProvider.value below) so the root lifecycle
  // observer can call handleAppResumed() directly. Reason: if the
  // user backgrounds the app mid-IAP-sheet, StoreKit may never
  // deliver a terminal stream event — the safety timer inside the
  // provider covers that, but a resume is a good additional cue
  // to drop a stale "purchasing" state.
  late final SubscriptionProvider _subscriptionProvider;
  final FCMService _fcm = FCMService();

  // Debounce app_opened so lock/unlock spam doesn't inflate session count.
  // Plan: pettrack-backend/docs/plans/2026-05-12-debug-dashboard.md.
  static const Duration _appOpenDebounce = Duration(seconds: 60);
  DateTime? _lastAppOpenedAt;

  void _maybeFireAppOpened() {
    final now = DateTime.now();
    if (_lastAppOpenedAt != null &&
        now.difference(_lastAppOpenedAt!) < _appOpenDebounce) {
      return;
    }
    _lastAppOpenedAt = now;
    AppEventService.fire('app_opened');
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Build the NotificationProvider eagerly so the FCM service can hand
    // it inbound messages (and so `bell badge` updates the moment a push
    // lands while the user is in the app).
    _notificationProvider = NotificationProvider()..initialize();

    // SubscriptionProvider is constructed eagerly too. initialize() is
    // still called lazily from PettiMainTabsScreen.initState after the
    // user is signed in — that method is idempotent.
    _subscriptionProvider = SubscriptionProvider();

    // Defer FCM initialization to the first post-frame callback so the
    // navigator key is mounted before any cold-start tap tries to push a
    // route via getInitialMessage(). Without this guard, a user tapping
    // a notification from a terminated state could cause a navigate-
    // before-runApp race.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fcm.initialize(notificationProvider: _notificationProvider);
      // First app_opened on cold start. Pre-login is fine — the backend
      // accepts userId='anon' for unauthenticated launches.
      _maybeFireAppOpened();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeFireAppOpened();
      // Give the subscription provider a chance to recover from a
      // stuck "purchasing" state. See SubscriptionProvider.handleAppResumed
      // for the full rationale.
      _subscriptionProvider.handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TraccarProvider()),
        // SubscriptionProvider owns: subscription status, IAP flow,
        // /me + /verify-purchase calls. Initialized lazily from
        // PettiMainTabsScreen.initState — see that file for the
        // initialize() call. Constructed eagerly above so the root
        // lifecycle observer can call handleAppResumed() on it.
        ChangeNotifierProvider.value(value: _subscriptionProvider),
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
        title: 'Besti',
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
