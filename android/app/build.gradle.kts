// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ✅ REMOVED: repositories block — does not belong in app-level build.gradle.kts.
// It belongs in settings.gradle.kts under dependencyResolutionManagement.

android {
    namespace = "com.example.ringtask"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // ✅ Required by flutter_local_notifications
    }

    kotlin {
        jvmToolchain(17)
    }

    defaultConfig {
        applicationId = "com.example.ringtask"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // ✅ Required for large dependency count
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ KEPT: Core library desugaring — required by flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation ("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    // ✅ ADDED: WorkManager — required for reliable background task execution
    // and foreground service support on Android 12+
    implementation("androidx.work:work-runtime-ktx:2.9.1")

    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
}