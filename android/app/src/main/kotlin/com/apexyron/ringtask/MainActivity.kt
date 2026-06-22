
package com.apexyron.ringtask

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.appcompat.app.AlertDialog

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "RingTaskMainActivity"
        private const val CHANNEL_ALARM = "ringtask/workmanager"
        private const val CHANNEL_FILE_UTILS = "ringtask/file_utils"
        private const val PREFS_NAME = "ringtask_alarms"
        const val EXTRA_IS_FAKE_CALL = "is_fake_call"
        const val EXTRA_CALL_PAYLOAD = "payload"
        private const val REQUEST_CODE_RINGTONE_PICKER = 999

        // Permission / settings request codes
        private const val REQUEST_CODE_POST_NOTIFICATIONS = 1001
        private const val REQUEST_CODE_OVERLAY = 1002
        private const val REQUEST_CODE_SCHEDULE_EXACT_ALARM = 1003
        private const val REQUEST_CODE_IGNORE_BATTERY = 1004
    }

    private var alarmChannel: MethodChannel? = null
    private var pendingFakeCallPayload: String? = null
    private var ringtoneResult: MethodChannel.Result? = null

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "MainActivity created — Android API ${Build.VERSION.SDK_INT}")
        FakeCallTrigger.ensureNotificationChannel(this)

        if (intent?.getBooleanExtra(EXTRA_IS_FAKE_CALL, false) == true) {
            applyLockScreenFlags()
        }
    }

    override fun onRestart() {
        super.onRestart()
        flutterEngine?.lifecycleChannel?.appIsResumed()
        // Re-check permissions when the activity restarts (user may have returned from settings)
        requestPermissionsIfNeeded()
    }

    override fun onResume() {
        super.onResume()
        flutterEngine?.lifecycleChannel?.appIsResumed()
    }

    // ── Engine Configuration ──────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupAlarmChannel(flutterEngine)
        setupFileUtilsChannel(flutterEngine)
        cacheIntentPayloadIfNeeded(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.i(TAG, "onNewIntent: action=${intent.action}")

        if (intent.getBooleanExtra(EXTRA_IS_FAKE_CALL, false)) {
            applyLockScreenFlags()

            val payload = intent.getStringExtra(EXTRA_CALL_PAYLOAD)
            val channel = alarmChannel
            if (channel != null) {
                Log.i(TAG, "onNewIntent: invoking onFakeCallAnswered directly")
                channel.invokeMethod("onFakeCallAnswered", payload)
            } else {
                Log.w(TAG, "onNewIntent: channel not ready yet, caching payload")
                pendingFakeCallPayload = payload
            }
        }
    }

    // ── Lock Screen Window Flags ──────────────────────────────────────────────

    private fun applyLockScreenFlags() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            Log.d(TAG, "Lock screen flags applied to MainActivity")
        } catch (e: Exception) {
            Log.e(TAG, "Error applying lock screen flags", e)
        }
    }

    // permission prompt helper

    private fun showSettingsPrompt(
        title: String,
        message: String,
        settingsIntent: Intent,
        requestCode: Int
    ) {
        if (isFinishing || (Build.VERSION.SDK_INT >= 17 && isDestroyed)) return

        try {
            AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setCancelable(false) // Force user to make a choice during setup
                .setPositiveButton("Open Settings") { _, _ ->
                    try {
                        startActivityForResult(settingsIntent, requestCode)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open settings intent", e)
                    }
                }
                .setNegativeButton("Not now") { dialog, _ ->
                    dialog.dismiss()
                }
                .show()
        } catch (e: Exception) {
            Log.e(TAG, "Error showing settings prompt", e)
            // fallback: just open settings without dialog if it's safe
            if (!isFinishing && !(Build.VERSION.SDK_INT >= 17 && isDestroyed)) {
                try {
                    startActivityForResult(settingsIntent, requestCode)
                } catch (ignored: Exception) { }
            }
        }
    }

    // ── Method Channel Architecture ────────────────────────────────────────────

    private fun setupAlarmChannel(flutterEngine: FlutterEngine) {
        alarmChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_ALARM
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {

                    "scheduleFakeCall" -> {
                        try {
                            val delayMillis = call.argument<Number>("delayMillis")?.toLong() ?: 0L
                            val payload = call.argument<String>("payload") ?: ""
                            val tag = call.argument<String>("tag") ?: "fakeCall"
                            val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong()
                                ?: (System.currentTimeMillis() + delayMillis)

                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

                            // Ensure exact alarm permission where required (Android 12+)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                                Log.w(TAG, "SCHEDULE_EXACT_ALARM not granted — opening settings")
                                startActivityForResult(
                                    Intent(
                                        Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                        Uri.parse("package:$packageName")
                                    ),
                                    REQUEST_CODE_SCHEDULE_EXACT_ALARM
                                )
                                result.error(
                                    "PERMISSION_DENIED",
                                    "SCHEDULE_EXACT_ALARM not granted",
                                    null
                                )
                                return@setMethodCallHandler
                            }

                            // Generate a unique numeric request ID and persist it so we can reliably cancel later.
                            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                            val nextId = prefs.getInt("alarm_id_counter", 0) + 1
                            prefs.edit().putInt("alarm_id_counter", nextId).apply()
                            val requestCode = nextId

                            val alarmIntent = Intent(applicationContext, AlarmReceiver::class.java).apply {
                                action = AlarmReceiver.ACTION_FAKE_CALL
                                putExtra(AlarmReceiver.EXTRA_PAYLOAD, payload)
                            }

                            val pendingIntent = PendingIntent.getBroadcast(
                                applicationContext,
                                requestCode,
                                alarmIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            // ✅ SWITCH: setAlarmClock is the most reliable for long-term tasks
                            // and ensures the alarm triggers at the exact time even in deep Doze.
                            val showIntent = Intent(applicationContext, MainActivity::class.java).apply {
                                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            }
                            val showPendingIntent = PendingIntent.getActivity(
                                applicationContext,
                                requestCode,
                                showIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            alarmManager.setAlarmClock(
                                AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent),
                                pendingIntent
                            )

                            // Save loop metadata if applicable
                            LoopManager.saveLoopTask(applicationContext, tag, payload)

                            // Save alarm using new format: triggerAtMillis|requestCode|payload
                            saveAlarm(tag, triggerAtMillis, payload, requestCode)
                            Log.i(TAG, "Exact alarm configured: tag=$tag id=$requestCode triggerAt=$triggerAtMillis")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error scheduling alarm", e)
                            result.error("SCHEDULE_ERROR", e.message, null)
                        }
                    }

                    "cancelFakeCall" -> {
                        try {
                            val tag = call.argument<String>("tag") ?: "fakeCall"
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

                            // Read stored entry to find the numeric requestCode (new format: triggerAtMillis|id|payload)
                            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                            val entry = prefs.getString(tag, null)
                            val requestCode = if (entry != null) {
                                val parts = entry.split("|", limit = 3)
                                if (parts.size >= 2) {
                                    // if parts.size == 2 then it's legacy format (no id), fallback to tag-based id
                                    if (parts.size == 2) {
                                        tag.toIntOrNull() ?: (tag.hashCode() and 0x7FFFFFFF)
                                    } else {
                                        parts[1].toIntOrNull() ?: (tag.toIntOrNull() ?: (tag.hashCode() and 0x7FFFFFFF))
                                    }
                                } else {
                                    (tag.toIntOrNull() ?: (tag.hashCode() and 0x7FFFFFFF))
                                }
                            } else {
                                // no saved entry — fallback to previous behavior
                                (tag.toIntOrNull() ?: (tag.hashCode() and 0x7FFFFFFF))
                            }

                            val alarmIntent = Intent(applicationContext, AlarmReceiver::class.java).apply {
                                action = AlarmReceiver.ACTION_FAKE_CALL
                            }

                            val pendingIntent = PendingIntent.getBroadcast(
                                applicationContext,
                                requestCode,
                                alarmIntent,
                                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                            )

                            pendingIntent?.let {
                                alarmManager.cancel(it)
                                it.cancel()
                            }

                            LoopManager.removeLoopTask(applicationContext, tag)
                            deleteAlarm(tag)
                            Log.i(TAG, "Cancelled persistent alarm database record for tag=$tag")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error cancelling alarm", e)
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }

                    "triggerFakeCall" -> {
                        try {
                            val payload = call.argument<String>("payload")
                            // ✅ FIX: Use FakeCallTrigger.fire to ensure it works from background
                            // by posting a notification with full-screen intent.
                            FakeCallTrigger.fire(applicationContext, payload)
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error triggering fake call", e)
                            result.error("TRIGGER_ERROR", e.message, null)
                        }
                    }

                    "flutterReady" -> {
                        Log.i(TAG, "flutterReady received, flushing cached pendingPayload=$pendingFakeCallPayload")
                        val payload = pendingFakeCallPayload
                        pendingFakeCallPayload = null
                        if (payload != null) {
                            channel.invokeMethod("onFakeCallAnswered", payload)
                        }
                        result.success(null)
                    }

                    "pickRingtone" -> {
                        ringtoneResult = result
                        val intent = Intent(android.media.RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_TYPE, android.media.RingtoneManager.TYPE_RINGTONE)
                            putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Ringtone")
                            putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, null as Uri?)
                        }
                        startActivityForResult(intent, REQUEST_CODE_RINGTONE_PICKER)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_RINGTONE_PICKER) {
            val result = ringtoneResult ?: return
            ringtoneResult = null

            if (resultCode == RESULT_OK) {
                val uri = data?.getParcelableExtra<Uri>(android.media.RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                result.success(uri?.toString())
            } else {
                result.success(null)
            }
            return
        }

        // If we returned from any settings screen, re-run checks (overlay, exact alarm, battery)
        if (requestCode == REQUEST_CODE_OVERLAY
            || requestCode == REQUEST_CODE_SCHEDULE_EXACT_ALARM
            || requestCode == REQUEST_CODE_IGNORE_BATTERY
            || requestCode == REQUEST_CODE_POST_NOTIFICATIONS) {
            // Give the system a moment to apply changes, then re-check.
            requestPermissionsIfNeeded()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Re-run the orchestration after user responded to runtime permission dialogs.
        if (requestCode == REQUEST_CODE_POST_NOTIFICATIONS) {
            requestPermissionsIfNeeded()
        }
    }

    private fun setupFileUtilsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_FILE_UTILS
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "readContentUri" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("INVALID_ARG", "uri argument is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse(uriString)
                        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }

                        if (bytes != null) {
                            result.success(bytes)
                        } else {
                            result.error(
                                "READ_FAILED",
                                "InputStream was null for URI: $uriString",
                                null
                            )
                        }
                    } catch (e: SecurityException) {
                        result.error("PERMISSION_DENIED", e.message, null)
                    } catch (e: Exception) {
                        result.error("READ_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Payload Processing ───────────────────────────────────────────────────

    private fun cacheIntentPayloadIfNeeded(intent: Intent?) {
        // Only cache during cold start (configureFlutterEngine).
        // onNewIntent handles the warm/hot path directly — do not cache there.
        if (intent?.getBooleanExtra(EXTRA_IS_FAKE_CALL, false) != true) return
        val payload = intent.getStringExtra(EXTRA_CALL_PAYLOAD)
        pendingFakeCallPayload = payload
        Log.i(TAG, "Cold-start: fake call payload cached — will deliver via flutterReady: $payload")
    }
    // ── Persistent Shared Storage Synchronization ────────────────────────────

    // New save format includes numeric id: triggerAtMillis|id|payload
    private fun saveAlarm(tag: String, triggerAtMillis: Long, payload: String, id: Int) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(tag, "$triggerAtMillis|$id|$payload")
            .apply()
    }

    private fun deleteAlarm(tag: String) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().remove(tag).apply()
    }

    // ── Foreground / OS Permission Orchestration ─────────────────────────────

    private fun requestPermissionsIfNeeded() {
        if (isFinishing || (Build.VERSION.SDK_INT >= 17 && isDestroyed)) return

        val prefs = getSharedPreferences("ringtask_config", Context.MODE_PRIVATE)
        val setupCompleted = prefs.getBoolean("initial_setup_completed", false)

        // 1) POST_NOTIFICATIONS runtime permission (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                // If setup is already completed and they denied notifications, don't nag every resume.
                // But during "Getting Started", we must prompt.
                if (setupCompleted) {
                    Log.d(TAG, "Notifications not granted but setup already completed — not prompting")
                } else {
                    try {
                        AlertDialog.Builder(this)
                            .setTitle("Allow notifications")
                            .setMessage("RingTask needs notification permission to show alarms and reminders. Please allow notifications so alarms can alert you on time.")
                            .setCancelable(false)
                            .setPositiveButton("Allow") { _, _ ->
                                try {
                                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE_POST_NOTIFICATIONS)
                                } catch (e: Exception) {
                                    Log.e(TAG, "Failed to request POST_NOTIFICATIONS", e)
                                }
                            }
                            .setNegativeButton("Not now") { dialog, _ -> dialog.dismiss() }
                            .show()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error showing notification permission dialog", e)
                        try {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE_POST_NOTIFICATIONS)
                        } catch (ex: Exception) { }
                    }
                    return
                }
            }
        }

        // 2) Appear on top (overlay) permission (Android M+) - CRITICAL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                // Critical permission: we prompt even if setupCompleted is true if it's missing, 
                // but during initial setup we make it non-cancelable.
                val overlayIntent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                showSettingsPrompt(
                    title = "Allow Appear on Top",
                    message = "RingTask needs the \"Appear on top\" permission to show the incoming call screen when an alarm triggers. This is essential for the app to function properly.",
                    settingsIntent = overlayIntent,
                    requestCode = REQUEST_CODE_OVERLAY
                )
                return
            }
        }

        // 3) SCHEDULE_EXACT_ALARM (Alarms & reminders) — Android 12+ (S) - CRITICAL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                val exactAlarmIntent = Intent(
                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:$packageName")
                )
                showSettingsPrompt(
                    title = "Allow Alarms & Reminders",
                    message = "To ensure your tasks remind you at the exact scheduled time, please allow \"Alarms & reminders\" in settings. Without this, reminders may be delayed.",
                    settingsIntent = exactAlarmIntent,
                    requestCode = REQUEST_CODE_SCHEDULE_EXACT_ALARM
                )
                return
            }
        }

        // If we reach here, critical permissions are granted.
        // We can now skip the non-critical ones if setup was already completed once.
        if (setupCompleted) {
            Log.d(TAG, "Critical permissions verified, setup already completed previously.")
            return
        }

        // 4) Full-screen intent permission (Android 14+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!nm.canUseFullScreenIntent()) {
                val fullScreenIntent = Intent(
                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                    Uri.parse("package:$packageName")
                )
                showSettingsPrompt(
                    title = "Full-screen Intents",
                    message = "To show incoming fake calls as a full-screen interruption, please enable full-screen intent usage for RingTask in settings.",
                    settingsIntent = fullScreenIntent,
                    requestCode = REQUEST_CODE_POST_NOTIFICATIONS 
                )
                return
            }
        }

        // 5) Battery optimization exemption
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                showSettingsPrompt(
                    title = "Disable Battery Optimizations",
                    message = "To ensure alarms and reminders fire reliably even when your phone is idle, please exempt RingTask from battery optimizations.",
                    settingsIntent = intent,
                    requestCode = REQUEST_CODE_IGNORE_BATTERY
                )
                return
            }
        }

        // Finalize initial setup
        prefs.edit().putBoolean("initial_setup_completed", true).apply()
        Log.i(TAG, "All platform-level background/draw-over restrictions verified successfully")
    }
}