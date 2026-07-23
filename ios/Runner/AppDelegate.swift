import Flutter
import FirebaseCore
import FirebaseMessaging
import GoogleMaps
import UIKit
import os.log

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps iOS SDK requires the API key before any GMSMapView is
    // created. Without this, the iOS Maps SDK aborts the process when the
    // first map widget is built — symptom is the app closing instantly
    // when the user navigates to DeviceDetailScreen.
    //
    // This is an iOS-restricted key (Maps SDK for iOS only, bundle id
    // co.pettrack.pettrackApp) created in Google Cloud Console under the
    // pettrack-colombia project on 2026-05-06. Android uses a separate
    // key — see android/app/src/main/AndroidManifest.xml. Do NOT reuse
    // the Android key here; it's restricted to "Android apps" and Google
    // returns unauthorized, which manifests as a blank/grey map at runtime.
    GMSServices.provideAPIKey("AIzaSyCPRk0Wp1dylUJK4YLOjsVqys1K_9gfH0A")
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // 2026-07-22: under the scene-lifecycle Flutter template the
    // firebase_messaging plugin's launch hook never runs, so nothing ever
    // calls registerForRemoteNotifications() — SpringBoard logged the app
    // as "without push registration" and no APNs token was ever issued.
    // Register explicitly. Harmless pre-permission: iOS issues the token
    // for silent pushes; visible-alert delivery still gates on the
    // UNUserNotificationCenter permission the app requests at login.
    application.registerForRemoteNotifications()
    return result
  }

  // 2026-07-22: Firebase's app-delegate swizzling does not deliver the APNs
  // device token to the FCM SDK under the scene-lifecycle Flutter template
  // (FlutterImplicitEngineDelegate). Symptom: getAPNSToken() stays null and
  // getToken() throws apns-token-not-set, so the FCM token is never minted
  // or registered with the backend. Hand the token to Firebase explicitly.
  // FirebaseApp is configured from Dart (DefaultFirebaseOptions), which can
  // race this callback on a cold start — guard, and let the super chain
  // forward to Flutter plugins either way; firebase_messaging re-applies
  // the token once it initializes.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    os_log("PetTrack: APNs device token received (%{public}d bytes)", deviceToken.count)
    applyApnsToken(deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // When iOS has a cached APNs token this callback fires within the first
  // second of launch — BEFORE the Dart side has run Firebase.initializeApp,
  // so FirebaseApp.app() is still nil and Messaging.messaging() would crash.
  // A plain nil-guard silently loses the token on every warm launch (only
  // the very first cold registration is slow enough to win the race).
  // Retry until Firebase is configured (Dart's getAPNSToken poll waits up
  // to ~30s, so 0.5s × 40 comfortably covers app init).
  private func applyApnsToken(_ deviceToken: Data, attempt: Int = 0) {
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
      os_log("PetTrack: APNs token handed to FCM (attempt %{public}d)", attempt)
      return
    }
    guard attempt < 40 else {
      os_log("PetTrack: gave up handing APNs token to FCM — FirebaseApp never configured")
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.applyApnsToken(deviceToken, attempt: attempt + 1)
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    os_log("PetTrack: APNs registration FAILED: %{public}@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
