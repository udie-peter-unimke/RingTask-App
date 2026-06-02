# Implementation Plan - Fix Play Store Red Flags

This plan addresses critical issues that would cause Google Play Store rejection, including invalid SDK versions, high-risk permissions, and improper signing configurations.

## Proposed Changes

### Android Build Configuration
Lower the SDK version from "Preview" to "Stable" and prepare the signing configuration for production.

#### [build.gradle.kts](file:///C:/Documents/Flutterprojects/ringtask/android/app/build.gradle.kts)
- Change `compileSdk` to 35.
- Change `targetSdk` to 35.
- Update `compileOptions` to use `JavaVersion.VERSION_17` (standard for Flutter 3.x).
- Placeholder for production signing config.

### Android Manifest
Remove high-risk/unnecessary permissions that lead to automatic rejection.

#### [AndroidManifest.xml](file:///C:/Documents/Flutterprojects/ringtask/android/app/src/main/AndroidManifest.xml)
- Remove `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- Remove `SYSTEM_ALERT_WINDOW` if redundant with Full Screen Intent (Optional but recommended for strict reviews).
- Ensure `FOREGROUND_SERVICE_TYPE` is correctly declared.

### App Source Code
Remove the logic that triggers intrusive permission requests on startup.

#### [MainActivity.kt](file:///C:/Documents/Flutterprojects/ringtask/android/app/src/main/kotlin/com/apexyron/ringtask/MainActivity.kt)
- Remove the code that opens the "Battery Optimization" settings.
- Refactor `requestPermissionsIfNeeded` to be less aggressive.

---

## Verification Plan

### Automated Tests
- Run `flutter build appbundle` to ensure the project still compiles after SDK downgrades.
- Check generated `AndroidManifest.xml` in the build folder to verify permissions are removed.

### Manual Verification
- Deploy to a physical device/emulator.
- Verify the app no longer asks to "Ignore Battery Optimizations" on launch.
- Verify "Virtual Call" still works using the `USE_FULL_SCREEN_INTENT` flow.
