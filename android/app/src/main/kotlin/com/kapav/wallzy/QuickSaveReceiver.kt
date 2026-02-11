package com.kapav.wallzy

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import androidx.core.app.NotificationCompat
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.Data
import android.util.Log
import org.json.JSONObject

class QuickSaveReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == "com.kapav.wallzy.QUICK_SAVE_ACTION") {
            val notificationId = intent.getIntExtra("notification_id", -1)
            val transactionJson = intent.getStringExtra("transaction_json")

            if (notificationId != -1 && transactionJson != null) {
                // 1. Show "Saving..." Notification
                showSavingNotification(context, notificationId)

                try {
                    val jsonObj = JSONObject(transactionJson)
                    val id = jsonObj.optString("id")
                    if (id.isNotEmpty()) {
                        SmsTransactionParser.removeTransaction(context, id)
                    }
                } catch (e: Exception) {
                    Log.e("QuickSaveReceiver", "Error parsing ID for removal", e)
                }

                // 2. Schedule WorkManager Task
                scheduleQuickSaveWork(context, transactionJson, notificationId)
            }
        }
    }

    private fun showSavingNotification(context: Context, notificationId: Int) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Re-build notification with progress/spinner
        val builder = NotificationCompat.Builder(context, "transaction_channel") // Use same channel as original
            .setSmallIcon(R.drawable.ic_stat_ledgr)
            .setContentTitle("Saving transaction to Ledgr")
            //.setContentText("Please wait")
            .setProgress(0, 0, true) // Indeterminate progress
            .setOngoing(true)
            .setAutoCancel(false)

        notificationManager.notify(notificationId, builder.build())
    }

    private fun scheduleQuickSaveWork(context: Context, transactionJson: String, notificationId: Int) {
        try {
            // Save JSON to SharedPreferences (FlutterSharedPreferences) in a QUEUE.
            // This ensures meaningful data is available even if WorkManager drops the InputData.
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val queueKey = "flutter.native_pending_quick_saves"
            
            // Read existing queue
            val existingJson = prefs.getString(queueKey, "[]") ?: "[]"
            val jsonArray = org.json.JSONArray(existingJson)
            
            // Add new transaction to queue
            // We wrap it in a wrapper to include the notification ID conveniently
            val wrapper = JSONObject()
            wrapper.put("notificationId", notificationId)
            wrapper.put("data", JSONObject(transactionJson))
            
            jsonArray.put(wrapper)
            
            // Save back
            prefs.edit().putString(queueKey, jsonArray.toString()).apply()
            Log.d("QuickSaveReceiver", "Queued transaction. Queue size: ${jsonArray.length()}")
            
            val dataBuilder = Data.Builder()
            
            // Set Task Name (Try both old and new keys to be safe)
            dataBuilder.putString("be.tramckrijte.workmanager.DART_TASK", "quick_save_transaction")
            dataBuilder.putString("dev.fluttercommunity.workmanager.DART_TASK", "quick_save_transaction")
            
            // Pass ONLY the ID. The Dart side will fetch the big JSON from Prefs.
            dataBuilder.putInt("notification_id", notificationId)

            val inputData = dataBuilder.build()

            // Resolve BackgroundWorker Class (Support both packages)
            var workerClass: Class<out androidx.work.ListenableWorker>? = null
            try {
                workerClass = Class.forName("dev.fluttercommunity.workmanager.BackgroundWorker") as Class<out androidx.work.ListenableWorker>
            } catch (e: ClassNotFoundException) {
                try {
                    workerClass = Class.forName("be.tramckrijte.workmanager.BackgroundWorker") as Class<out androidx.work.ListenableWorker>
                } catch (e2: ClassNotFoundException) {
                    Log.e("QuickSaveReceiver", "Could not find BackgroundWorker class!")
                    throw e2
                }
            }

            if (workerClass != null) {
                val request = OneTimeWorkRequest.Builder(workerClass)
                    .setInputData(inputData)
                    .addTag("quick_save_transaction")
                    .build()

                WorkManager.getInstance(context).enqueue(request)
                Log.d("QuickSaveReceiver", "Work enqueued for transaction $notificationId")
            }

        } catch (e: Exception) {
            Log.e("QuickSaveReceiver", "Error scheduling work", e)
             // Fallback: Notify error locally so user isn't stuck
            showErrorNotification(context, notificationId)
        }
    }
    
    private fun showErrorNotification(context: Context, notificationId: Int) {
         val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
         val builder = NotificationCompat.Builder(context, "transaction_channel")
            .setSmallIcon(R.drawable.ic_stat_ledgr)
            .setContentTitle("Quick Save Error")
            .setContentText("Could not start background save.")
            .setAutoCancel(true)
            
         notificationManager.notify(notificationId, builder.build())
    }
}
