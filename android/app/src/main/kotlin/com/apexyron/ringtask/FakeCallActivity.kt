package com.example.ringtask

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.widget.LinearLayout
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity

class FakeCallActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "FakeCallActivity"
        private val VIBRATION_PATTERN = longArrayOf(0L, 1000L, 500L)
    }

    private var payload: String? = null
    private var ringtone: android.media.Ringtone? = null
    private var vibrator: Vibrator? = null
    private var localWakeLock: PowerManager.WakeLock? = null

    // Track whether the user took a deliberate action (answer/decline).
    // If true, onPause should NOT stop the ringtone — we want it to keep
    // playing until forwardToFlutter() completes the transition.
    private var userActed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        applyScreenFlags()

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        localWakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ringtask:FakeCallActivity"
        )
        localWakeLock?.acquire(30_000L)

        payload = intent.getStringExtra(MainActivity.EXTRA_CALL_PAYLOAD)

        setContentView(R.layout.activity_fake_call)

        val btnAnswer = findViewById<LinearLayout>(R.id.btnAnswer)
        val btnDecline = findViewById<LinearLayout>(R.id.btnDecline)

        btnAnswer.setOnClickListener {
            userActed = true
            stopRingtoneAndVibration()
            forwardToFlutter(payload)
            finish()
        }

        // Single declaration — the duplicate is removed
        btnDecline.setOnClickListener {
            userActed = true
            stopRingtoneAndVibration()
            finish()
        }

        startRingtoneAndVibration()
        Log.i(TAG, "FakeCallActivity created — payload=$payload")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        payload = intent.getStringExtra(MainActivity.EXTRA_CALL_PAYLOAD)
        userActed = false  // reset for the new call
        Log.i(TAG, "onNewIntent — new payload=$payload")
        stopRingtoneAndVibration()
        startRingtoneAndVibration()
    }

    override fun onPause() {
        super.onPause()
        // ONLY stop media if the user did NOT take a deliberate action.
        // Without this guard, the ringtone is killed during the brief window
        // reconstruction that happens when Android wakes the screen —
        // before the user has even seen the fake call UI.
        if (!userActed) {
            stopRingtoneAndVibration()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (localWakeLock?.isHeld == true) {
                localWakeLock?.release()
            }
        } catch (_: Exception) {}
        localWakeLock = null

        stopRingtoneAndVibration()
        Log.i(TAG, "FakeCallActivity destroyed")
    }

    private fun applyScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun startRingtoneAndVibration() {
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(applicationContext, ringtoneUri)?.also {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    it.isLooping = true
                    it.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                }
                it.play()
                Log.i(TAG, "Ringtone started")
            }

            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            vibrator?.let { v ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createWaveform(VIBRATION_PATTERN, 0))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(VIBRATION_PATTERN, 0)
                }
                Log.i(TAG, "Vibration started")
            }
        } catch (e: Exception) {
            Log.e(TAG, "startRingtoneAndVibration failed", e)
        }
    }

    private fun stopRingtoneAndVibration() {
        try {
            ringtone?.stop()
            ringtone = null
            vibrator?.cancel()
            vibrator = null
            Log.i(TAG, "Ringtone and vibration stopped")
        } catch (e: Exception) {
            Log.e(TAG, "stopRingtoneAndVibration failed", e)
        }
    }

    private fun forwardToFlutter(payload: String?) {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            // FLAG_ACTIVITY_CLEAR_TOP was the culprit — it destroyed and
            // recreated MainActivity, causing the surface reconstruction race.
            // SINGLE_TOP alone brings the existing instance to the front
            // and delivers the payload via onNewIntent without rebuilding it.
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_CALL_PAYLOAD, payload)
            putExtra(MainActivity.EXTRA_IS_FAKE_CALL, true)
        }
        startActivity(mainIntent)
    }
}