package com.apexyron.ringtask

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.widget.LinearLayout
import android.widget.TextView
import android.view.View
import android.view.WindowManager
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.view.animation.AccelerateDecelerateInterpolator
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject
import java.io.File

class FakeCallActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "FakeCallActivity"
        private val VIBRATION_PATTERN = longArrayOf(0L, 1000L, 500L)
    }

    private var payload: String? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var localWakeLock: PowerManager.WakeLock? = null
    private var screenWakeLock: PowerManager.WakeLock? = null
    private var pulseAnimatorSet: AnimatorSet? = null

    // Track whether the user took a deliberate action (answer/decline).
    // If true, onPause should NOT stop the ringtone — we want it to keep
    // playing until forwardToFlutter() completes the transition.
    private var userActed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        applyScreenFlags()
        super.onCreate(savedInstanceState)

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        localWakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ringtask:FakeCallActivity"
        )
        localWakeLock?.acquire(30_000L)

        // Wake screen specifically
        screenWakeLock = pm.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
            "ringtask:FakeCallActivity:WakeScreen"
        )
        screenWakeLock?.acquire(10_000L)

        payload = intent.getStringExtra(MainActivity.EXTRA_CALL_PAYLOAD)

        setContentView(R.layout.activity_fake_call)

        updateUi(payload)

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
        startPulseAnimation()
        Log.i(TAG, "FakeCallActivity created — payload=$payload")
    }

    override fun onNewIntent(intent: Intent) {
        applyScreenFlags()
        super.onNewIntent(intent)
        setIntent(intent)
        payload = intent.getStringExtra(MainActivity.EXTRA_CALL_PAYLOAD)
        userActed = false  // reset for the new call
        Log.i(TAG, "onNewIntent — new payload=$payload")
        updateUi(payload)
        stopRingtoneAndVibration()
        stopPulseAnimation()
        startRingtoneAndVibration()
        startPulseAnimation()
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
        stopPulseAnimation()
        try {
            if (localWakeLock?.isHeld == true) {
                localWakeLock?.release()
            }
        } catch (_: Exception) {}
        localWakeLock = null

        try {
            if (screenWakeLock?.isHeld == true) {
                screenWakeLock?.release()
            }
        } catch (_: Exception) {}
        screenWakeLock = null

        stopRingtoneAndVibration()
        Log.i(TAG, "FakeCallActivity destroyed")
    }

    private fun applyScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        
        // Always add these flags for better compatibility across versions
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    private fun startPulseAnimation() {
        val pulseContainer = findViewById<View>(R.id.pulseContainer) ?: return
        val pulseCircle1 = findViewById<View>(R.id.pulseCircle1) ?: return
        val pulseCircle2 = findViewById<View>(R.id.pulseCircle2) ?: return

        pulseAnimatorSet = AnimatorSet().apply {
            val anim1 = createPulseAnimator(pulseCircle1, 0)
            val anim2 = createPulseAnimator(pulseCircle2, 750)
            val containerScaleX = ObjectAnimator.ofFloat(pulseContainer, "scaleX", 1.0f, 1.1f).apply {
                duration = 750
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                interpolator = AccelerateDecelerateInterpolator()
            }
            val containerScaleY = ObjectAnimator.ofFloat(pulseContainer, "scaleY", 1.0f, 1.1f).apply {
                duration = 750
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                interpolator = AccelerateDecelerateInterpolator()
            }

            playTogether(anim1, anim2, containerScaleX, containerScaleY)
            start()
        }
    }

    private fun createPulseAnimator(view: View, startDelayTime: Long): AnimatorSet {
        val scaleX = ObjectAnimator.ofFloat(view, "scaleX", 1.0f, 2.5f)
        val scaleY = ObjectAnimator.ofFloat(view, "scaleY", 1.0f, 2.5f)
        val alpha = ObjectAnimator.ofFloat(view, "alpha", 0.6f, 0.0f)

        return AnimatorSet().apply {
            playTogether(scaleX, scaleY, alpha)
            duration = 1500
            startDelay = startDelayTime
            interpolator = AccelerateDecelerateInterpolator()
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    if (pulseAnimatorSet?.isRunning == true) {
                        start()
                    }
                }
            })
        }
    }

    private fun stopPulseAnimation() {
        pulseAnimatorSet?.cancel()
        pulseAnimatorSet = null
    }

    private fun updateUi(payload: String?) {
        try {
            payload?.let { p ->
                val json = JSONObject(p)
                val title = json.optString("title", "Task Reminder")
                val caller = json.optString("callerName", "RingTask Reminder")

                findViewById<TextView>(R.id.tvCallerName)?.text = caller
                findViewById<TextView>(R.id.tvTaskTitle)?.text = title
            }
        } catch (e: Exception) {
            Log.e(TAG, "updateUi failed", e)
        }
    }

    private fun startRingtoneAndVibration() {
        try {
            // 🎵 Custom Ringtone Logic
            var ringtoneUri: Uri? = null
            try {
                payload?.let { p ->
                    val json = JSONObject(p)
                    if (json.has("ringtonePath")) {
                        val path = json.getString("ringtonePath")
                        if (!path.isNullOrEmpty() && path != "null") {
                            // Support both file paths and content URIs
                            ringtoneUri = if (path.startsWith("content://")) {
                                Uri.parse(path)
                            } else {
                                val file = File(path)
                                if (file.exists()) Uri.fromFile(file) else null
                            }
                            Log.i(TAG, "Using custom ringtone path/uri: $path")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing ringtone from payload", e)
            }

            // Fallback to default
            if (ringtoneUri == null) {
                ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }

            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, ringtoneUri!!)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
            Log.i(TAG, "MediaPlayer started with URI: $ringtoneUri")

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
            val player = mediaPlayer
            mediaPlayer = null
            
            // Release the player asynchronously. mediaPlayer.release() can be 
            // a blocking IPC call on some devices, adding latency to the 
            // activity transition.
            if (player != null) {
                Thread {
                    try {
                        if (player.isPlaying) player.stop()
                        player.release()
                        Log.i(TAG, "MediaPlayer released on background thread")
                    } catch (e: Exception) {
                        Log.e(TAG, "Async release failed", e)
                    }
                }.start()
            }

            vibrator?.cancel()
            vibrator = null
            Log.i(TAG, "Vibration stopped")
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