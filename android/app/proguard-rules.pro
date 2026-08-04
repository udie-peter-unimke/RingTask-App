# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# 1. Preserve Line Numbers for readable Crashlytics logs
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# 2. Fix for the R8 Play Store split-install warning we solved earlier
-dontwarn com.google.android.play.core.**

# 3. ONLY if you use native Java/Kotlin data models with Firebase reflection:
# Instead of keeping all of Firebase, target ONLY your specific model classes if needed.
# Example (uncomment and update path if you have native data models):
# -keep class com.yourcompany.ringtask.models.** { *; }