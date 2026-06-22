package com.apexyron.ringtask

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import java.util.Calendar

object LoopManager {
    private const val TAG = "LoopManager"
    private const val PREFS_LOOP_TASKS = "ringtask_loop_tasks"

    fun saveLoopTask(context: Context, taskId: String, payload: String) {
        try {
            val json = JSONObject(payload)
            if (!json.has("recurrence") || json.isNull("recurrence")) {
                return
            }

            context.getSharedPreferences(PREFS_LOOP_TASKS, Context.MODE_PRIVATE)
                .edit()
                .putString(taskId, payload)
                .apply()
            Log.i(TAG, "Saved loop task metadata for taskId=$taskId")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving loop task metadata", e)
        }
    }

    fun removeLoopTask(context: Context, taskId: String) {
        context.getSharedPreferences(PREFS_LOOP_TASKS, Context.MODE_PRIVATE)
            .edit()
            .remove(taskId)
            .apply()
        Log.i(TAG, "Removed loop task metadata for taskId=$taskId")
    }

    fun rescheduleNext(context: Context, taskId: String, lastTriggerAt: Long = System.currentTimeMillis()) {
        val prefs = context.getSharedPreferences(PREFS_LOOP_TASKS, Context.MODE_PRIVATE)
        val payload = prefs.getString(taskId, null) ?: return

        try {
            val json = JSONObject(payload)
            val recurrence = json.optString("recurrence")
            if (recurrence.isEmpty()) return

            val nextTriggerAt = calculateNextOccurrence(lastTriggerAt, recurrence)
            
            scheduleNativeAlarm(context, taskId, payload, nextTriggerAt)
            Log.i(TAG, "Rescheduled loop task taskId=$taskId for next occurrence: $nextTriggerAt ($recurrence)")
        } catch (e: Exception) {
            Log.e(TAG, "Error rescheduling loop task", e)
        }
    }

    private fun calculateNextOccurrence(lastTriggerAt: Long, recurrence: String): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = lastTriggerAt

        when (recurrence) {
            "daily" -> calendar.add(Calendar.DAY_OF_YEAR, 1)
            "weekly" -> calendar.add(Calendar.WEEK_OF_YEAR, 1)
            "monthly" -> calendar.add(Calendar.MONTH, 1)
            else -> calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        val now = System.currentTimeMillis()
        while (calendar.timeInMillis <= now) {
            when (recurrence) {
                "daily" -> calendar.add(Calendar.DAY_OF_YEAR, 1)
                "weekly" -> calendar.add(Calendar.WEEK_OF_YEAR, 1)
                "monthly" -> calendar.add(Calendar.MONTH, 1)
            }
        }

        return calendar.timeInMillis
    }

    private fun scheduleNativeAlarm(context: Context, taskId: String, payload: String, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val requestCode = taskId.toIntOrNull() ?: (taskId.hashCode() and 0x7FFFFFFF)

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

        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent),
            pendingIntent
        )

        saveAlarmRecord(context, taskId, triggerAtMillis, payload, requestCode)
    }

    private fun saveAlarmRecord(context: Context, tag: String, triggerAtMillis: Long, payload: String, id: Int) {
        context.getSharedPreferences("ringtask_alarms", Context.MODE_PRIVATE)
            .edit()
            .putString(tag, "$triggerAtMillis|$id|$payload")
            .apply()
    }
}
