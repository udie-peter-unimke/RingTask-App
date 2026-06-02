package com.example.ringtask

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log
import org.json.JSONObject

object FakeCallTrigger {

    private const val TAG = "FakeCallTrigger"
    const val CHANNEL_ID = "fake_call_channel_v2"

    // Tracks whether the channel has been created in this process lifetime.
    // Avoids the delete/recreate cycle that causes Android to rate-limit
    // and silently drop the full-screen intent.
    private var channelCreated = false

    fun fire(context: Context, payload: String?) {
        if (payload.isNullOrEmpty()) {
            Log.e(TAG, "FakeCallTrigger.fire: empty payload")
            AlarmReceiver.releaseWakeLock()
            return
        }

        try {
            val data = JSONObject(payload)
            val title = data.optString("title", "Task Reminder")
            val callerName = data.optString("callerName", "RingTask Reminder")

            Log.i(TAG, "FakeCallTrigger.fire() — title=$title callerName=$callerName")

            ensureNotificationChannel(context)
            postCallNotification(context, callerName, title, payload)

            // ✅ Force the Activity to launch automatically
            // This works from the background if "Display over other apps" is granted.
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(MainActivity.EXTRA_IS_FAKE_CALL, true)
                putExtra(MainActivity.EXTRA_CALL_PAYLOAD, payload)
            }
            context.startActivity(intent)

            Log.i(TAG, "FakeCallTrigger fired successfully: notification posted and Activity launch attempted")
        } catch (e: Exception) {
            Log.e(TAG, "FakeCallTrigger.fire() failed critical initialization", e)
        } finally {
            AlarmReceiver.releaseWakeLock()
        }
    }

    fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        // Only create once per process lifetime. Deleting and recreating the
        // channel on every alarm fires is the primary cause of the full-screen
        // intent being suppressed — Android rate-limits channel churn and posts
        // to a transiently missing channel fall back to a silent banner.
        //
        // If you need to change channel settings (importance, sound, etc.),
        // bump CHANNEL_ID to a new string (e.g. "fake_call_channel_v3") and
        // do a one-time migration instead of deleting on every call.
        if (channelCreated) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Only delete if the old v1 channel still exists from a previous install.
        // This is a one-time migration, not a per-alarm operation.
        manager.deleteNotificationChannel("fake_call_channel")  // v1 cleanup only

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Fake Incoming Call",
            NotificationManager.IMPORTANCE_HIGH
            // IMPORTANCE_MAX is functionally identical to IMPORTANCE_HIGH for
            // full-screen intents. MAX caused some OEMs (Xiaomi, Oppo) to
            // reclassify the channel as spam after 2-3 firings and block it.
        ).apply {
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setSound(null, null)
            enableVibration(false)
            setBypassDnd(true)
        }

        manager.createNotificationChannel(channel)
        channelCreated = true
        Log.i(TAG, "Notification channel created: $CHANNEL_ID")
    }

    private fun postCallNotification(
        context: Context,
        callerName: String,
        title: String,
        payload: String
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notificationId = System.currentTimeMillis().toInt() and 0x7FFFFFFF

        // ✅ Launch MainActivity directly instead of FakeCallActivity
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_IS_FAKE_CALL, true)
            putExtra(MainActivity.EXTRA_CALL_PAYLOAD, payload)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(callerName)
            .setContentText("Incoming Call – $title")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSound(null)
            .setVibrate(null)
            .build()

        manager.notify(notificationId, notification)
        Log.i(TAG, "Call notification posted: id=$notificationId caller=$callerName")
    }
}