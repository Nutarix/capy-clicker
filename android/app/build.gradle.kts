import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key for Google Play: android/key.properties (never in git).
// How to create it: store/RELEASE.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

fun keystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }
        ?: throw GradleException(
            "android/key.properties has no '$name'. " +
                "Expected storeFile, storePassword, keyAlias, keyPassword (see store/RELEASE.md).",
        )

android {
    namespace = "com.nutarix.capy_clicker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Google Play app id. Cannot change after the first upload to the store.
        applicationId = "com.nutarix.capy_clicker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // From `version:` in pubspec.yaml (name+code).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val store = file(keystoreProperty("storeFile"))
                if (!store.exists()) {
                    throw GradleException(
                        "Upload keystore not found: $store (storeFile in android/key.properties).",
                    )
                }
                storeFile = store
                storePassword = keystoreProperty("storePassword")
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Never the debug key: without key.properties release tasks fail below.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Fail fast, before compiling, when a release package is requested without
// the upload key. Debug builds and tests do not need it.
gradle.taskGraph.whenReady {
    val releasePackaging = Regex("^(assemble|bundle|package|sign|install)Release.*")
    val wantsRelease = allTasks.any { it.project == project && releasePackaging.matches(it.name) }
    if (wantsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release signing key not found: android/key.properties is missing. " +
                "Release builds are never signed with the debug key. " +
                "Create the upload key and key.properties as described in store/RELEASE.md. " +
                "Debug builds (flutter run, flutter build apk --debug) do not need it.",
        )
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
