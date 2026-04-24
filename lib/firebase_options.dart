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
    // Real Firebase-generated App ID (fetched from Firebase Console →
    // Project Settings → General → Your apps → pettrack-web). The previous
    // value "pettrackcolombiawebapp" was a hand-written placeholder that
    // broke Firebase JS SDK init on web, surfacing as cloud_firestore/unavailable.
    appId: '1:487348630652:web:235441c835ccfa0f3905f9',
    messagingSenderId: '487348630652',
    projectId: 'pettrack-colombia',
    // authDomain is required for Firebase Auth + Firestore to work on web.
    // Default format: <projectId>.firebaseapp.com.
    authDomain: 'pettrack-colombia.firebaseapp.com',
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
