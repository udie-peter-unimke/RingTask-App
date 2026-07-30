package com.apexyron.ringtask

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "ringtask/workmanager"
        
        const val EXTRA_IS_FAKE_CALL = "isFakeCall"
        const val EXTRA_CALL_PAYLOAD = "payload"
    }

    private var methodChannel: MethodChannel? = null
    private var pendingPayload: String? = null
    private var isFlutterReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockscreenFlags()
        
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "flutterReady" -> {
                    isFlutterReady = true
                    Log.i(TAG, "Flutter is ready")
                    
                    // Flush any pending payload that arrived before Flutter was ready
                    pendingPayload?.let {
                        Log.i(TAG, "Flushing pending payload to Flutter")
                        methodChannel?.invokeMethod("onFakeCallAnswered", it)
                        pendingPayload = null
                    }
                    result.success(true)
                }
                "triggerFakeCall" -> {
                    val payload = call.argument<String>("payload")
                    FakeCallTrigger.fire(this, payload)
                    result.success(true)
                }
                "scheduleFakeCall" -> {
                    val triggerAtMillis = call.argument<Long>("triggerAtMillis")
                    val tag = call.argument<String>("tag")
                    val payload = call.argument<String>("payload")

                    if (triggerAtMillis != null && tag != null && payload != null) {
                        scheduleAlarm(tag, triggerAtMillis, payload)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing triggerAtMillis, tag, or payload", null)
                    }
                }
                "cancelFakeCall" -> {
                    val tag = call.argument<String>("tag")
                    cancelAlarm(tag)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val isFakeCall = intent.getBooleanExtra(EXTRA_IS_FAKE_CALL, false)
        val payload = intent.getStringExtra(EXTRA_CALL_PAYLOAD)

        if (isFakeCall && payload != null) {
            Log.i(TAG, "Incoming fake call answered - payload received")
            applyLockscreenFlags()
            dismissKeyguard()
            
            // Explicitly request dismiss again for safety on transition
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                km.requestDismissKeyguard(this, null)
            }

            if (isFlutterReady) {
                methodChannel?.invokeMethod("onFakeCallAnswered", payload)
            } else {
                Log.i(TAG, "Flutter not ready, caching payload")
                pendingPayload = payload
            }
        }
    }

    private fun applyLockscreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
    }

    private fun dismissKeyguard() {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            km.requestDismissKeyguard(this, null)
        }
    }

    private fun scheduleAlarm(tag: String, triggerAtMillis: Long, payload: String) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val requestCode = tag.toIntOrNull() ?: (tag.hashCode() and 0x7FFFFFFF)

            val intent = Intent(this, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_FAKE_CALL
                putExtra(AlarmReceiver.EXTRA_PAYLOAD, payload)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // For high reliability, use setAlarmClock which wakes up the device
            // and shows up in the system's "upcoming alarms".
            val showIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val showPendingIntent = PendingIntent.getActivity(
                this,
                requestCode,
                showIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent),
                pendingIntent
            )

            // Save record for reboot persistence
            getSharedPreferences("ringtask_alarms", Context.MODE_PRIVATE)
                .edit()
                .putString(tag, "$triggerAtMillis|$requestCode|$payload")
                .apply()

            Log.i(TAG, "Scheduled alarm via MainActivity: tag=$tag triggerAt=$triggerAtMillis")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm", e)
        }
    }

    private fun cancelAlarm(tag: String?) {
        if (tag == null) return
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val requestCode = tag.toIntOrNull() ?: (tag.hashCode() and 0x7FFFFFFF)
            
            val intent = Intent(this, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this, 
                requestCode, 
                intent, 
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.i(TAG, "Cancelled alarm for tag=$tag")
            }
            
            // Also remove from records
            getSharedPreferences("ringtask_alarms", Context.MODE_PRIVATE)
                .edit()
                .remove(tag)
                .apply()
                
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel alarm", e)
        }
    }
}
