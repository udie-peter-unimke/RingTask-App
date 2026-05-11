package com.example.ringtask

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity

class FakeCallActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "FakeCallActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Apply lockscreen/wakelock flags first — this is why this activity exists.
        // Note: MainActivity also has showWhenLocked/turnScreenOn in the manifest,
        // so the Flutter call UI will remain visible after this activity finishes.
        applyScreenFlags()
        dismissKeyguard()

        val payload = intent.getStringExtra(MainActivity.EXTRA_CALL_PAYLOAD)
        Log.i(TAG, "FakeCallActivity: forwarding to Flutter, payload=$payload")

        // Hand off to Flutter immediately — FakeCallScreen handles all UI/audio
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_CALL_PAYLOAD, payload)
            putExtra(MainActivity.EXTRA_IS_FAKE_CALL, true)
        }
        startActivity(mainIntent)
        finish() // FakeCallActivity only exists to set lockscreen flags
    }

    private fun applyScreenFlags() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            Log.d(TAG, "Screen flags applied")
        } catch (e: Exception) {
            Log.e(TAG, "Error applying screen flags", e)
        }
    }

    private fun dismissKeyguard() {
        try {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                km.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() { Log.d(TAG, "Keyguard dismissed") }
                    override fun onDismissError() { Log.w(TAG, "Keyguard dismiss error") }
                    override fun onDismissCancelled() { Log.w(TAG, "Keyguard dismiss cancelled") }
                })
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing keyguard", e)
        }
    }
}