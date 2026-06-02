# Implementation Plan - Improve Long-Term Scheduling Reliability

The goal is to fix the issue where scheduled fake calls do not trigger at the exact time for long-term tasks. The primary solution is to switch from `setExactAndAllowWhileIdle` to `setAlarmClock`, which is the most reliable way to schedule user-visible alarms in Android and is less restricted by Doze mode and App Standby buckets.

## User Review Required

> [!NOTE]
> Switching to `setAlarmClock` will cause a small alarm icon to appear in the system status bar, as it is treated as a system-level alarm. This is generally expected for a task reminder app but is a visible change.

## Proposed Changes

### Android Native (Kotlin)

#### [MainActivity.kt](file:///C:/Documents/Flutterprojects/ringtask/android/app/src/main/kotlin/com/apexyron/ringtask/MainActivity.kt)

- Add a check for `Build.VERSION.SDK_INT >= Build.VERSION_CODES.S` before calling `canScheduleExactAlarms()` to prevent crashes on Android 11 and below.
- Replace `alarmManager.setExactAndAllowWhileIdle` with `alarmManager.setAlarmClock`.
- Create a `PendingIntent` for the `AlarmClockInfo`'s `showIntent` to allow users to open the app by tapping the alarm in the system UI.

#### [BootReceiver.kt](file:///C:/Documents/Flutterprojects/ringtask/android/app/src/main/kotlin/com/apexyron/ringtask/BootReceiver.kt)

- Update the `rescheduleAlarms` method to also use `setAlarmClock` instead of `setExactAndAllowWhileIdle` for consistency and reliability.

### Flutter (Dart)

- No changes required in Dart code as the interface to the native side remains the same (`triggerAtMillis` and `payload`).

## Verification Plan

### Automated Tests
- I will verify the code compiles and handle the logic correctly via static analysis (checking for API level compatibility).
- Since I cannot run the app for long periods, I will rely on the fact that `setAlarmClock` is the documented best practice for exact alarms.

### Manual Verification
1.  **Short-term check**: Schedule an alarm for 1 minute from now. Verify it pops up.
2.  **Mock Long-term check**: Ensure the logic for `setAlarmClock` correctly passes the `triggerAtMillis`.
3.  **Boot check**: Simulate a boot (if possible via ADB) or verify the `rescheduleAlarms` logic in `BootReceiver`.
4.  **API Level check**: Verify that the code doesn't call API 31+ methods on older devices.
