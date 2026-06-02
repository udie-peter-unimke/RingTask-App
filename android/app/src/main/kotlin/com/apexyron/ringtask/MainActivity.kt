package com.example.ringtask

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

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "RingTaskMainActivity"
        private const val CHANNEL_ALARM = "ringtask/workmanager"
        private const val CHANNEL_FILE_UTILS = "ringtask/file_utils"
        private const val PREFS_NAME = "ringtask_alarms"
        const val EXTRA_IS_FAKE_CALL = "is_fake_call"
        const val EXTRA_CALL_PAYLOAD = "payload"
    }

    private var alarmChannel: MethodChannel? = null
    private var pendingFakeCallPayload: String? = null

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "MainActivity created — Android API ${Build.VERSION.SDK_INT}")
        FakeCallTrigger.ensureNotificationChannel(this)
        requestPermissionsIfNeeded()

        if (intent?.getBooleanExtra(EXTRA_IS_FAKE_CALL, false) == true) {
            applyLockScreenFlags()
        }
    }



    override fun onRestart() {
        super.onRestart()
        flutterEngine?.lifecycleChannel?.appIsResumed()
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
                Log.i(TAG, "onNewIntent: invoking navigateToFakeCall directly")
                channel.invokeMethod("navigateToFakeCall", payload)
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

                            // Ensure exact alarm permission where required
                            if (!alarmManager.canScheduleExactAlarms()) {
                                Log.w(TAG, "SCHEDULE_EXACT_ALARM not granted — opening settings")
                                startActivity(
                                    Intent(
                                        Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                        Uri.parse("package:$packageName")
                                    )
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

                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                triggerAtMillis,
                                pendingIntent
                            )

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
                            applyLockScreenFlags()
                            alarmChannel?.invokeMethod("navigateToFakeCall", payload)
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
                            channel.invokeMethod("navigateToFakeCall", payload)
                        }
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
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
        val prefs = getSharedPreferences("ringtask_config", Context.MODE_PRIVATE)

        if (prefs.getBoolean("permissions_requested", false)) {
            Log.d(TAG, "Permissions already processed previously — skipping prompts")
            return
        }
        prefs.edit().putBoolean("permissions_requested", true).apply()

        // Request runtime POST_NOTIFICATIONS on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
                // Return early to show the permission dialog; user will continue later.
                return
            }
        }

        if (!Settings.canDrawOverlays(this)) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
            )
            return
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName")
                )
            )
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!nm.canUseFullScreenIntent()) {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                        Uri.parse("package:$packageName")
                    )
                )
                return
            }
        }

        Log.i(TAG, "All platform-level background/draw-over restrictions verified successfully")
    }
}