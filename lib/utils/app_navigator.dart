import 'package:flutter/material.dart';

/// Global keys for navigator + scaffold messenger.
///
/// Why these exist: certain code paths need to push a screen or show a
/// SnackBar from outside the widget tree's BuildContext. The two main cases
/// in PetTrack are:
///
///   1. FCM message handlers (foreground / background / terminated). FCM
///      callbacks run as top-level functions or service methods that don't
///      receive a BuildContext, but they need to navigate the user to
///      `AlertDetailScreen` when a push notification is tapped.
///
///   2. Background services that surface in-app banners (e.g. SMS-transport
///      command result toasts when a reply lands via webhook).
///
/// Plug both keys into `MaterialApp` once, in `main.dart`. From anywhere
/// else in the app, call:
///
///     AppNavigator.navigator.push(MaterialPageRoute(builder: ...));
///     AppNavigator.scaffoldMessenger.showSnackBar(...);
///
/// or use `currentState` directly if you need to handle a missing widget
/// tree (e.g. during cold-start before runApp has mounted).
class AppNavigator {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// The current NavigatorState. Throws if the app isn't mounted yet —
  /// callers that fire during cold-start should use `currentState` and
  /// handle null themselves.
  static NavigatorState get navigator => navigatorKey.currentState!;

  /// The current ScaffoldMessengerState. Same null caveat as `navigator`.
  static ScaffoldMessengerState get scaffoldMessenger =>
      scaffoldMessengerKey.currentState!;

  /// True if the app is mounted and we can push routes / show banners.
  /// Use this guard in handlers that may fire before runApp completes.
  static bool get isMounted => navigatorKey.currentState != null;
}
