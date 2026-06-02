package com.example.ringtask

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "ringtask_alarms"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val validActions = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED
        )
        if (intent.action !in validActions) return

        Log.i(TAG, "onReceive: action=${intent.action} — rescheduling pending alarms")

        val pendingResult = goAsync()
        try {
            rescheduleAlarms(context)
        } finally {
            pendingResult.finish()
        }
    }

    // 💡 Helper for context: format is "$triggerAtMillis|$id|$payload"
    private fun saveAlarm(context: Context, tag: String, triggerAtMillis: Long, payload: String, id: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(tag, "$triggerAtMillis|$id|$payload").apply()
    }

    private fun rescheduleAlarms(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val allEntries = prefs.all

        if (allEntries.isEmpty()) {
            Log.i(TAG, "No saved alarms to restore")
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        var rescheduled = 0
        var firedMissed = 0
        var failed = 0

        for ((tag, value) in allEntries) {
            val entry = (value as? String) ?: continue

            // 🛠️ Fixed: Adjusted parsing schema to split into 3 parts (triggerAtMillis, requestCode, payload)
            val parts = entry.split("|", limit = 3)
            if (parts.size != 3) {
                Log.w(TAG, "Invalid entry format for tag=$tag")
                continue
            }

            val triggerAtMillis = parts[0].toLongOrNull()
            if (triggerAtMillis == null) {
                Log.w(TAG, "Invalid trigger time for tag=$tag")
                continue
            }

            val requestCode = parts[1].toIntOrNull() ?: (tag.hashCode() and 0x7FFFFFFF)
            val payload = parts[2]

            if (triggerAtMillis <= now) {
                // ✅ Fix #1: No FakeCallService — fire directly via FakeCallTrigger.
                //            Acquire WakeLock first so CPU stays alive through the call.
                Log.w(TAG, "Alarm $tag missed during reboot — firing directly")
                try {
                    AlarmReceiver.acquireWakeLockStatic(context)
                    FakeCallTrigger.fire(context, payload)
                    prefs.edit().remove(tag).apply()
                    firedMissed++
                } catch (e: Exception) {
                    Log.e(TAG, "Failed firing missed alarm tag=$tag", e)
                    AlarmReceiver.releaseWakeLock() // release if fire() never got to its finally
                    failed++
                }

            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    !alarmManager.canScheduleExactAlarms()
                ) {
                    Log.w(TAG, "SCHEDULE_EXACT_ALARM not granted — skipping tag=$tag")
                    failed++
                    continue
                }

                val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_FAKE_CALL
                    putExtra(AlarmReceiver.EXTRA_PAYLOAD, payload)
                }

                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    alarmIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )

                Log.i(TAG, "Rescheduled: tag=$tag triggerAt=$triggerAtMillis requestCode=$requestCode")
                rescheduled++
            }
        }

        Log.i(TAG, "Boot reschedule complete — rescheduled=$rescheduled firedMissed=$firedMissed failed=$failed")
    }
}