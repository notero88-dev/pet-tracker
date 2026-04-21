# PetTrack Mobile App

Flutter app for PetTrack pet GPS tracking service (Colombia market).

## Setup

### Prerequisites
- Flutter 3.41+ 
- Android Studio / Xcode
- Firebase project configured

### Installation

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK (Android)
flutter build apk --release

# Build iOS (Mac only)
flutter build ios --release
```

### Firebase Configuration

Firebase config files are already in place:
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

### Backend URLs

Update `lib/utils/constants.dart` if backend URLs change:
- Traccar: http://64.23.156.25:8082
- Provisioning API: http://64.23.156.25:3000
- Push Service: http://64.23.156.25:3001

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── providers/                # State management (Provider)
│   └── auth_provider.dart    # Firebase Auth
├── screens/                  # UI screens
│   ├── splash_screen.dart
│   ├── auth/                 # Login, register, password reset
│   └── home/                 # Main app screens
├── services/                 # API clients, WebSocket
├── widgets/                  # Reusable UI components
└── utils/                    # Constants, theme, helpers
    ├── constants.dart
    └── theme.dart
```

## Sprint Progress

- [x] **A-001: Flutter Scaffold** (Sprint 2, Phase 1B)
  - Project structure ✅
  - Dependencies configured ✅
  - Firebase configs ✅
  - App theme (Colombian green/orange) ✅
  - Auth provider (Firebase) ✅
  - Splash screen ✅

- [ ] **A-002: Auth Flow** (Next)
  - Login screen
  - Registration screen
  - Password reset
  
- [ ] **A-003: Traccar API Client**
- [ ] **A-004: Device Onboarding**

## Dependencies

### Firebase
- firebase_core
- firebase_auth
- firebase_storage
- firebase_messaging

### Maps & Location
- google_maps_flutter
- location
- geocoding

### State Management
- provider

### Networking
- http
- web_socket_channel

### QR Scanning
- mobile_scanner

### UI
- image_picker
- flutter_svg
- intl (Spanish localization)

## Building

### Android
```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS (Mac required)
```bash
flutter build ios --release
```

## Troubleshooting

**Android build fails:**
- Check `android/app/google-services.json` exists
- Run `flutter clean && flutter pub get`

**iOS build fails:**
- Check `ios/Runner/GoogleService-Info.plist` exists
- Run `pod install` in `ios/` directory

**Firebase errors:**
- Verify Firebase project ID matches
- Check Firebase console for app registration

## Environment

- Development: Local emulator
- Staging: TBD
- Production: Google Play + App Store

---

**Sprint 2 Goal:** Basic app with auth + device onboarding  
**Status:** A-001 complete ✅ (Scaffold ready)
