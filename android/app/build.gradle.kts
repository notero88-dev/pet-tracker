plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Processes google-services.json (must come AFTER the Android plugin).
    id("com.google.gms.google-services")
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
