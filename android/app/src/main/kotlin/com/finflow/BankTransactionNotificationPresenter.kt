package com.finflow

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object BankTransactionNotificationPresenter {
    const val channelId = "finflow_transaction_detection_v2"
    const val notificationIdExtra = "finflow_bank_notification_id"
    private const val logTag = "FinFlowBankImport"

    fun cancel(context: Context, id: String) {
        context.getSystemService(NotificationManager::class.java)
            .cancel(id.take(8).hashCode())
    }

    fun show(context: Context, id: String): Boolean {
        ensureChannel(context)
        if (!areEnabled(context)) {
            Log.w(logTag, "App notifications are disabled")
            BankNotificationStore.recordDiagnostic(
                context,
                "last_post_status",
                "notifications_disabled",
            )
            return false
        }
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        intent.putExtra(notificationIdExtra, id)
        val pendingIntent = PendingIntent.getActivity(
            context,
            id.take(8).hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification_finflow)
            .setContentTitle("FinFlow phát hiện giao dịch mới")
            .setContentText("Chạm để kiểm tra và lưu giao dịch.")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Chạm để kiểm tra và lưu giao dịch.",
                ),
            )
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setColor(Color.rgb(0, 134, 106))
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .build()
        return try {
            context.getSystemService(NotificationManager::class.java)
                .notify(id.take(8).hashCode(), notification)
            BankNotificationStore.recordDiagnostic(context, "last_post_status", "posted")
            BankNotificationStore.recordDiagnostic(
                context,
                "last_posted_at",
                System.currentTimeMillis(),
            )
            Log.i(logTag, "FinFlow confirmation notification posted")
            true
        } catch (error: SecurityException) {
            Log.e(logTag, "FinFlow is not allowed to post notifications", error)
            BankNotificationStore.recordDiagnostic(
                context,
                "last_post_status",
                "security_error",
            )
            false
        } catch (error: RuntimeException) {
            Log.e(logTag, "Unable to post transaction notification", error)
            BankNotificationStore.recordDiagnostic(
                context,
                "last_post_status",
                "runtime_error:${error.javaClass.simpleName}",
            )
            false
        }
    }

    fun areEnabled(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val channel = context.getSystemService(NotificationManager::class.java)
            .getNotificationChannel(channelId)
        return channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Giao dịch được phát hiện",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Nhắc kiểm tra giao dịch từ ngân hàng và ví điện tử"
                    enableVibration(true)
                    enableLights(true)
                    lightColor = Color.rgb(0, 134, 106)
                },
            )
    }
}
