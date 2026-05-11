package com.example.ringtask

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "RingTaskMainActivity"
        private const val CHANNEL = "ringtask/workmanager"
        const val EXTRA_IS_FAKE_CALL = "is_fake_call"
        const val EXTRA_CALL_PAYLOAD = "payload"
    }

    private var methodChannel: MethodChannel? = null
    private var pendingFakeCallPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "MainActivity created - Android API ${Build.VERSION.SDK_INT}")
        checkFullScreenIntentPermission()
        requestBatteryOptimizationExemption()
        requestOverlayPermission() // ✅ Required for direct background activity launch
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                val method = call.method
                when (method) {

                    "scheduleFakeCall" -> {
                        try {
                            val delayMillis = call.argument<Number>("delayMillis")?.toLong() ?: 0L
                            val payload = call.argument<String>("payload") ?: ""
                            val tag = call.argument<String>("tag") ?: "fakeCall"

                            val inputData = Data.Builder()
                                .putString("payload", payload)
                                .build()

                            val request = OneTimeWorkRequestBuilder<FakeCallWorker>()
                                .setInitialDelay(delayMillis, TimeUnit.MILLISECONDS)
                                .setInputData(inputData)
                                .addTag(tag)
                                .addTag("fakeCall")
                                .build()

                            WorkManager.getInstance(applicationContext).enqueue(request)
                            Log.i(TAG, "FakeCallWorker scheduled in ${delayMillis}ms, tag=$tag")
                            result.success(request.id.toString())
                        } catch (e: Exception) {
                            Log.e(TAG, "Error scheduling FakeCallWorker", e)
                            result.error("SCHEDULE_ERROR", e.message, null)
                        }
                    }

                    "cancelFakeCall" -> {
                        try {
                            val tag = call.argument<String>("tag") ?: "fakeCall"
                            WorkManager.getInstance(applicationContext)
                                .cancelAllWorkByTag(tag)
                            Log.i(TAG, "Cancelled work with tag: $tag")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error cancelling fakeCall work", e)
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }

                    "triggerFakeCall" -> {
                        try {
                            val payload = call.argument<String>("payload")
                            launchFakeCallActivity(payload)
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error triggering FakeCallActivity", e)
                            result.error("TRIGGER_ERROR", e.message, null)
                        }
                    }

                    "flutterReady" -> {
                        Log.i(TAG, "Flutter signalled ready, pendingPayload=$pendingFakeCallPayload")
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

        handleFakeCallIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.i(TAG, "onNewIntent: action=${intent.action}")
        handleFakeCallIntent(intent)
    }

    private fun handleFakeCallIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_IS_FAKE_CALL, false) != true) return

        val payload = intent.getStringExtra(EXTRA_CALL_PAYLOAD)
        val channel = methodChannel

        if (channel == null) {
            Log.w(TAG, "Channel not ready yet, caching payload for flutterReady")
            pendingFakeCallPayload = payload
            return
        }

        Log.i(TAG, "Channel ready, invoking navigateToFakeCall directly")
        channel.invokeMethod("navigateToFakeCall", payload)
    }

    private fun launchFakeCallActivity(payload: String?) {
        val intent = Intent(this, FakeCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_IS_FAKE_CALL, true)
            if (payload != null) putExtra(EXTRA_CALL_PAYLOAD, payload)
        }
        startActivity(intent)
        Log.i(TAG, "FakeCallActivity launched with payload=$payload")
    }

    private fun checkFullScreenIntentPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!nm.canUseFullScreenIntent()) {
                Log.w(TAG, "USE_FULL_SCREEN_INTENT not granted — opening settings")
                val intent = Intent(
                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            }
        }
    }

    private fun requestBatteryOptimizationExemption() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            Log.w(TAG, "Battery optimization active — requesting exemption")
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        } else {
            Log.i(TAG, "Battery optimization already exempted")
        }
    }

    // ✅ SYSTEM_ALERT_WINDOW (Display over other apps) is required for
    // FakeCallWorker to launch FakeCallActivity directly from the background
    // when the screen is ON. Without this, Android 10+ blocks background
    // activity launches and only shows a heads-up notification instead.
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(this)
        ) {
            Log.w(TAG, "SYSTEM_ALERT_WINDOW not granted — opening settings")
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        } else {
            Log.i(TAG, "SYSTEM_ALERT_WINDOW already granted")
        }
    }
}