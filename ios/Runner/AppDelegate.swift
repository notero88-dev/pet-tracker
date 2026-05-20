import Flutter
import GoogleMaps
import UIKit

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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
