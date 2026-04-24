# Android Setup — first-time guide

How to get the PetTrack Flutter app running on Android, starting from a Mac
with no Android tooling installed. Should take 30–60 min the first time;
mostly waiting for downloads.

> **Why this doc exists:** Android Studio's onboarding has 6 wizards, 4
> SDK download steps, and 3 places where you can pick a "wrong" answer
> that costs you an hour. This page is the path that actually works for
> PetTrack on Apple Silicon. If a step here doesn't match what you see in
> Android Studio, the doc is probably out of date — please update it.

---

## Prerequisites

- macOS (Apple Silicon recommended for fast emulator)
- Homebrew installed (`brew --version` should work)
- Flutter installed (`flutter --version` should work)
- ~10 GB free disk space (Android Studio + SDK + an emulator image)

---

## Step 1 — Install Android Studio

```bash
brew install --cask android-studio
```

Or manual: https://developer.android.com/studio (download, drag to Applications).

This downloads ~3 GB. While waiting, read the rest of this doc.

---

## Step 2 — First-launch setup wizard

1. Open Android Studio from Applications
2. Setup wizard appears. Choose:
   - **Standard** install (not Custom)
   - Theme: whatever you prefer
   - SDK Components: accept the default selections (Android SDK, Emulator,
     SDK Platform, Build-Tools — all needed)
3. Wizard downloads ~5 GB more (SDK + emulator + a default system image).
   This is the longest single step. Coffee.
4. After it finishes, close any "Welcome to Android Studio" / "Open Project"
   window. We don't open the Flutter project from inside Android Studio —
   we use the IDE only as an SDK manager + AVD manager. The actual Flutter
   editing happens in your normal editor (VS Code, Cursor, etc.).

---

## Step 3 — Wire Flutter to the SDK + accept licenses

In your terminal:

```bash
flutter doctor -v
```

You should see:

```
[✓] Android toolchain - develop for Android devices (Android SDK version ...)
    • Android SDK at /Users/<you>/Library/Android/sdk
    • Some Android licenses not accepted. ...
```

If you instead see "Unable to locate Android SDK", point Flutter at the
install:

```bash
flutter config --android-sdk ~/Library/Android/sdk
flutter doctor -v
```

Then accept all SDK licenses (interactive — type `y` to each):

```bash
flutter doctor --android-licenses
```

Re-run `flutter doctor`. The Android section should now have a clean ✓.

---

## Step 4 — Create an emulator (AVD)

Inside Android Studio:

1. **Tools → Device Manager** (or click the phone icon in the toolbar)
2. Click **+ Create Device**
3. Pick **Pixel 7** — good middle-ground form factor
4. Click **Next**
5. System image:
   - Apple Silicon: pick the **API 34 (Android 14)** row, **arm64-v8a** column,
     **Google Play** variant (NOT "Google APIs" — Google Play has Play Services
     which is required for FCM push notifications to work on the emulator)
   - Intel Mac: same but **x86_64** column
6. If the row isn't downloaded yet, click the **⬇ download** arrow next to it.
   Another ~2 GB download. Wait for it to finish.
7. Click **Next → Finish**
8. Back in Device Manager, click the **▶ play button** next to the new AVD
9. The emulator window appears. First boot takes 1–2 minutes.

---

## Step 5 — Run the app

Back in terminal, in the Flutter app directory:

```bash
cd ~/Documents/pet_tracker_claude/app

# Should list the running emulator
flutter devices
# Look for: "sdk gphone64 arm64 (mobile)" with id "emulator-5554" (or similar)

# Pull deps
flutter pub get

# Run!
flutter run
```

First build takes 3–5 min (Gradle dependency resolution). Subsequent runs
with hot reload are <30s.

---

## What the app needs that's already in the repo

The following are already configured (commit `c499f8f`); you don't need to do
anything:

- `applicationId = "co.pettrack.app"` matching the Firebase Android app
- `com.google.gms.google-services` Gradle plugin applied
- Google Maps API key in `AndroidManifest.xml`
- Location + notifications permissions
- `google-services.json` checked into `android/app/`

---

## Likely first-run issues + fixes

### "Could not GET https://..." during Gradle dep resolution

Network blip during the dependency download. Easy fix:

```bash
flutter clean
flutter pub get
flutter run
```

### App boots but the map is blank gray

Maps SDK for Android isn't enabled for our API key. Fix in Google Cloud
Console:

1. https://console.cloud.google.com → select project `pettrack-colombia`
2. APIs & Services → Library
3. Search "Maps SDK for Android" → click → **Enable**
4. Restart the Flutter app (hot reload won't pick up server-side changes)

### App boots but Firebase Auth fails with `app-not-authorized` or similar

The debug keystore's SHA-1 fingerprint isn't registered with Firebase.

```bash
cd ~/Documents/pet_tracker_claude/app/android
./gradlew signingReport
```

Copy the `SHA1: ...` line for the **debug** variant. Then in Firebase
Console:

1. Project settings → Your apps → Android app `co.pettrack.app`
2. **Add fingerprint** → paste SHA-1 → save
3. Re-download `google-services.json`, replace
   `android/app/google-services.json`
4. `flutter clean && flutter run`

### FCM push notifications don't arrive

Two common causes:

1. AVD wasn't a "Google Play" image — recreate it (Step 4) with the right
   variant
2. App didn't request `POST_NOTIFICATIONS` permission at runtime — this is
   declared in `AndroidManifest.xml` but Android 13+ requires a runtime
   prompt. The Flutter `firebase_messaging` plugin handles this, but the
   prompt is only shown when you actually call
   `FirebaseMessaging.instance.requestPermission()` somewhere

### Build error: "No matching client found for package name"

The `applicationId` in `build.gradle.kts` doesn't match the package name in
`google-services.json`. Both should be `co.pettrack.app`. If they're not,
something has drifted — see commit `c499f8f` for what they should look
like.

### `flutter doctor` says "cmdline-tools component is missing"

Inside Android Studio: **Settings → Appearance & Behavior → System Settings
→ Android SDK → SDK Tools tab → check "Android SDK Command-line Tools
(latest)" → Apply**. ~100 MB download.

---

## Operational notes

- **Don't open the Flutter project from Android Studio.** Use Android
  Studio only as an SDK / AVD manager. Edit Flutter code in your usual
  editor (VS Code, Cursor, Sublime, vim, etc.).
- **First boot of the emulator is slow** — 1–2 min, then subsequent
  starts are ~15s.
- **Cold boot vs Quick boot:** Device Manager → ⋮ menu next to your AVD →
  "Cold Boot Now" if you suspect emulator state is stale (e.g. it remembers
  a stale Firebase Auth session and you can't reproduce a fresh sign-up).
- **Snapshot warm boots:** the default behavior. Faster but state persists.

---

## When this doc is wrong

If a step here breaks for you, fix it and commit the doc update. Future you
will thank you. Current Android Studio version this guide was written
against: **2025.3.4.6 (Panda 4)**, Flutter 3.41.3 stable, AGP 8.11.1.
