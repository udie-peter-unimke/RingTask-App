package com.example.ringtask

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject

class FakeCallWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    companion object {
        const val CHANNEL_ID = "fake_call_channel"
        const val NOTIFICATION_ID = 999999
        private const val TAG = "FakeCallWorker"
    }

    override fun doWork(): Result {
        return try {
            val payloadString = inputData.getString("payload")
                ?: run {
                    Log.e(TAG, "No payload in inputData")
                    return Result.failure()
                }

            Log.i(TAG, "FakeCallWorker fired: $payloadString")

            val data = JSONObject(payloadString)
            val title = data.optString("title", "Task Reminder")
            val callerName = data.optString("callerName", "RingTask Reminder")

            // Step 1 — Always post the notification.
            // Handles screen OFF / locked state via fullScreenIntent.
            postCallNotification(callerName, title, payloadString)

            // Step 2 — Also attempt a direct activity launch.
            // Handles screen ON + app backgrounded, where Android demotes
            // fullScreenIntent to a heads-up banner instead of auto-launching.
            // SYSTEM_ALERT_WINDOW permission (declared in manifest) is what
            // allows this on Android 10+. If not granted, this is a no-op.
            launchFakeCallActivity(payloadString)

            Log.i(TAG, "FakeCallWorker completed")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "FakeCallWorker FAILED", e)
            Result.failure()
        }
    }

    private fun launchFakeCallActivity(payload: String) {
        try {
            // SYSTEM_ALERT_WINDOW is required to start activities from background
            // on Android 10+. Check it is granted before attempting.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                !Settings.canDrawOverlays(applicationContext)
            ) {
                Log.w(TAG, "SYSTEM_ALERT_WINDOW not granted — skipping direct launch")
                return
            }

            val intent = Intent(applicationContext, FakeCallActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_NO_USER_ACTION or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(MainActivity.EXTRA_IS_FAKE_CALL, true)
                putExtra(MainActivity.EXTRA_CALL_PAYLOAD, payload)
            }
            applicationContext.startActivity(intent)
            Log.i(TAG, "FakeCallActivity direct launch sent")
        } catch (e: Exception) {
            // Non-fatal — notification fullScreenIntent is the fallback
            Log.w(TAG, "Direct launch failed (non-fatal): ${e.message}")
        }
    }

    private fun postCallNotification(callerName: String, title: String, payload: String) {
        val manager = applicationContext
            .getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Fake Incoming Call", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }

        val fullScreenIntent = Intent(applicationContext, FakeCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_IS_FAKE_CALL, true)
            putExtra(MainActivity.EXTRA_CALL_PAYLOAD, payload)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            applicationContext, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(callerName)
            .setContentText("Incoming Call – $title")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSound(null)
            .setVibrate(null)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
        Log.i(TAG, "Call notification posted")
    }
}