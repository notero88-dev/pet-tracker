import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCSAgHYzg74m6TNEx0Zw8NX7wb1IwGvkh0',
    appId: '1:487348630652:web:pettrackcolombiawebapp',
    messagingSenderId: '487348630652',
    projectId: 'pettrack-colombia',
    storageBucket: 'pettrack-colombia.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCSAgHYzg74m6TNEx0Zw8NX7wb1IwGvkh0',
    appId: '1:487348630652:android:af7aa56d5c008b813905f9',
    messagingSenderId: '487348630652',
    projectId: 'pettrack-colombia',
    storageBucket: 'pettrack-colombia.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAawSByoGwaIiqZc--PSI45Rl38wptzc7w',
    appId: '1:487348630652:ios:001e1cb9b2273ab33905f9',
    messagingSenderId: '487348630652',
    projectId: 'pettrack-colombia',
    storageBucket: 'pettrack-colombia.firebasestorage.app',
    iosBundleId: 'co.pettrack.app',
  );
}
