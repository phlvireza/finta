import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Loaded before the android block so both signingConfigs and buildTypes can
// branch on whether real signing credentials are present.
val keystoreProperties: Properties? =
    rootProject.file("key.properties").takeIf { it.exists() }?.let { f ->
        Properties().apply { f.inputStream().use { load(it) } }
    }

android {
    namespace = "com.finta.finta"
    // Pinned rather than tracking flutter.*, so a Flutter SDK upgrade cannot
    // move the API level under a release that has already been tested. Needs
    // Android platform 36 installed locally; Gradle fails loudly if it is not.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Permanent once published to Play — changing it ships a different app.
        applicationId = "com.finta.finta"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        // CONFIRM against Play's current target-API floor before each release —
        // it rises every August and a stale value blocks upload.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Credentials live in android/key.properties, which is gitignored and
        // never committed. Absent on a fresh clone, which is why the release
        // build type below checks for it rather than assuming it exists.
        if (keystoreProperties != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (keystoreProperties != null) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Fail loudly rather than silently falling back to the debug
                // key. Play rejects debug-signed artifacts, and the old
                // template default made that discoverable only at upload time.
                // Local `flutter run --release` still works via the debug
                // signing that AGP applies when no config is set.
                logger.warn(
                    "WARNING: android/key.properties not found. This release build is " +
                    "NOT signed with the upload key and cannot be published to Play."
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
