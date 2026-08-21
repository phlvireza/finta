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
                // Fall back to the debug key so the artifact is at least
                // installable. AGP does *not* sign a release build when no
                // signingConfig is set — it emits an unsigned APK, which
                // Android refuses to install at all ("App not installed",
                // even over an existing install). An earlier version of this
                // block left the branch empty on the assumption that AGP
                // substituted the debug key here; it does not.
                //
                // Play still rejects CN=Android Debug, which is what the
                // warning is for — but a local build that cannot be
                // installed is a worse failure than one that cannot be
                // published.
                signingConfig = signingConfigs.getByName("debug")
                logger.warn(
                    "WARNING: android/key.properties not found. This release build is " +
                    "signed with the DEBUG key: installable locally, but it cannot be " +
                    "published to Play."
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
