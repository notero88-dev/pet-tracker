import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Processes google-services.json (must come AFTER the Android plugin).
    id("com.google.gms.google-services")
}

// --- Release signing ---------------------------------------------------------
// Loaded from android/key.properties (gitignored). The properties file holds
// the keystore password and key alias for the production keystore at
// android/keystore/pettrack-release.keystore (also gitignored).
//
// Locally on the dev Mac these files are present and `flutter build apk
// --release` produces a Play-Store-uploadable APK/AAB. On CI or any machine
// without the keystore, the file is absent and we fall back to the debug key
// so debug builds still work — but release builds will fail-fast with a clear
// error pointing here, instead of silently shipping a debug-signed APK.
//
// Backup: keep a copy of pettrack-release.keystore + key.properties in a
// password manager (1Password). Losing the keystore means we can never push
// updates to the same Play Store listing — Google requires re-signing with
// the same certificate.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "co.pettrack.pettrack_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // applicationId is the install-time identity (Play Store + Firebase
        // verification). It MUST match the package_name registered in
        // google-services.json — Firebase will refuse to initialize otherwise.
        // Canonical PetTrack bundle is `co.pettrack.app` across iOS + Android.
        //
        // NOTE: `namespace` (above) is intentionally different (kept as
        // `co.pettrack.pettrack_app` to match MainActivity.kt's package on
        // disk). AGP 8+ separates the two cleanly:
        //   namespace     = where R.java is generated / Kotlin source root
        //   applicationId = the app's identity in the world
        // If you want to consolidate them later, rename the
        // android/app/src/main/kotlin/co/pettrack/pettrack_app/ directory
        // and update the `package` line in MainActivity.kt to match.
        applicationId = "co.pettrack.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release keystore when available; otherwise fall back to
            // debug so `flutter run --release` still works on machines that
            // don't have key.properties (CI without secrets, fresh checkouts).
            // For Play Store builds, key.properties MUST be present.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
