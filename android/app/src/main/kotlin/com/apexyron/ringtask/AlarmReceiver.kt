package com.example.ringtask

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FAKE_CALL = "com.example.ringtask.FAKE_CALL"
        const val EXTRA_PAYLOAD = "payload"
        private const val TAG = "AlarmReceiver"
        private const val WAKELOCK_TAG = "ringtask:AlarmReceiverWakeLock"
        private const val WAKELOCK_TIMEOUT_MS = 10_000L

        @Volatile
        private var wakeLock: PowerManager.WakeLock? = null

        fun releaseWakeLock() {
            try {
                wakeLock?.let {
                    if (it.isHeld) {
                        it.release()
                        Log.d(TAG, "WakeLock released")
                    }
                }
                wakeLock = null
            } catch (e: Exception) {
                Log.e(TAG, "WakeLock release failed", e)
            }
        }

        // ✅ Added: called by BootReceiver before firing missed alarms directly
        fun acquireWakeLockStatic(context: Context) {
            try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    WAKELOCK_TAG
                ).also {
                    it.acquire(WAKELOCK_TIMEOUT_MS)
                    Log.d(TAG, "WakeLock acquired (static) — timeout=${WAKELOCK_TIMEOUT_MS}ms")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to acquire WakeLock (static)", e)
            }
        }
    }


    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_FAKE_CALL) return

        val payload = intent.getStringExtra(EXTRA_PAYLOAD)
        if (payload.isNullOrEmpty()) {
            Log.e(TAG, "No payload — abort")
            return
        }

        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val localWakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG + ":local")
        try {
            localWakeLock.acquire(WAKELOCK_TIMEOUT_MS)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire local wakelock", e)
        }

        val pendingResult = goAsync()
        Thread {
            try {
                FakeCallTrigger.fire(context, payload)
            } catch (e: Exception) {
                Log.e(TAG, "FakeCallTrigger.fire() failed", e)
            } finally {
                try { if (localWakeLock.isHeld) localWakeLock.release() } catch (_: Exception) {}
                pendingResult.finish()
            }
        }.start()
    }

    private fun acquireWakeLock(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                WAKELOCK_TAG
            ).also {
                it.acquire(WAKELOCK_TIMEOUT_MS)
                Log.d(TAG, "WakeLock acquired — timeout=${WAKELOCK_TIMEOUT_MS}ms")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WakeLock", e)
        }
    }
}