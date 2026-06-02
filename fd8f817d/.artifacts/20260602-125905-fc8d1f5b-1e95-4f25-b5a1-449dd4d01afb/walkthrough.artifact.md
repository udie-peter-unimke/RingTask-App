# Walkthrough - Improve Long-Term Scheduling Reliability

I have improved the reliability of long-term scheduled fake calls by switching to the Android `setAlarmClock` API.

## Changes Made

### Android Native (Kotlin)

#### [MainActivity.kt](file:///C:/Documents/Flutterprojects/ringtask/android/app/src/main/kotlin/com/apexyron/ringtask/MainActivity.kt)

- **Switched to `setAlarmClock`**: This API is specifically designed for user-visible alarms and is highly prioritized by the Android system, even during Doze mode.
- **Added API 31+ Check**: Prevented crashes on Android 11 and below by wrapping the `canScheduleExactAlarms()` check in a version check.
- **Alarm Clock Info**: Configured the alarm to show the app's `MainActivity` if the user clicks on the alarm icon in the system UI.

#### [BootReceiver.kt](file:///C:/Documents/Flutterprojects/ringtask/android/app/src/main/kotlin/com/apexyron/ringtask/BootReceiver.kt)

- **Updated Rescheduling Logic**: Changed the boot-time rescheduling to use `setAlarmClock` as well, maintaining consistency across the app.

## Verification Summary

### Manual Verification
- **Code Review**: Verified that the use of `setAlarmClock` correctly passes the `triggerAtMillis` and `PendingIntent`.
- **API Compatibility**: Confirmed that the `Build.VERSION_CODES.S` check prevents invalid API calls on older devices.
- **Expected Behavior**: The system now shows an alarm icon when a call is scheduled, which is the trade-off for significantly better reliability.
