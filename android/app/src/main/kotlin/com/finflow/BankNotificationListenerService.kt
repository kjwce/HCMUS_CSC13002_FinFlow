package com.finflow

import android.app.Notification
import android.content.ComponentName
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.security.MessageDigest

class BankNotificationListenerService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(logTag, "Notification listener connected")
        BankNotificationStore.recordDiagnostic(this, "listener_state", "connected")
        BankNotificationStore.recordDiagnostic(
            this,
            "listener_connected_at",
            System.currentTimeMillis(),
        )
        recoverActiveNotifications()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(logTag, "Notification listener disconnected; requesting rebind")
        BankNotificationStore.recordDiagnostic(this, "listener_state", "disconnected")
        BankNotificationStore.recordDiagnostic(
            this,
            "listener_disconnected_at",
            System.currentTimeMillis(),
        )
        requestRebind(
            ComponentName(this, BankNotificationListenerService::class.java),
        )
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.w(logTag, "FinFlow task removed; keeping notification listener bound")
        BankNotificationStore.recordDiagnostic(
            this,
            "task_removed_at",
            System.currentTimeMillis(),
        )
        requestSystemRebind(this)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        processNotification(sbn, recoverExisting = false)
    }

    private fun recoverActiveNotifications() {
        if (!BankNotificationStore.isEnabled(this)) return
        try {
            val oldestRecoverablePostTime =
                System.currentTimeMillis() - activeRecoveryWindowMillis
            activeNotifications
                .filter { it.postTime >= oldestRecoverablePostTime }
                .sortedBy { it.postTime }
                .forEach { processNotification(it, recoverExisting = true) }
            BankNotificationStore.recordDiagnostic(
                this,
                "active_recovery_at",
                System.currentTimeMillis(),
            )
            BankNotificationStore.recordDiagnostic(
                this,
                "active_recovery_status",
                "success",
            )
        } catch (error: SecurityException) {
            Log.e(logTag, "Unable to recover active notifications", error)
            BankNotificationStore.recordDiagnostic(
                this,
                "active_recovery_status",
                "security_error",
            )
        } catch (error: RuntimeException) {
            Log.e(logTag, "Active notification recovery failed", error)
            BankNotificationStore.recordDiagnostic(
                this,
                "active_recovery_status",
                "runtime_error",
            )
        }
    }

    private fun processNotification(
        sbn: StatusBarNotification,
        recoverExisting: Boolean,
    ) {
        if (!BankNotificationStore.isEnabled(this)) return
        if (sbn.packageName == packageName) return
        if (!BankNotificationStore.enabledPackages(this).contains(sbn.packageName)) return
        BankNotificationStore.recordDiagnostic(this, "last_source_package", sbn.packageName)
        BankNotificationStore.recordDiagnostic(
            this,
            "last_source_received_at",
            System.currentTimeMillis(),
        )

        val extras = sbn.notification.extras
        val title = redact(
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty(),
        )
        val text = listOfNotNull(
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString(),
        ).map { redact(it.trim()) }.filter { it.isNotEmpty() }.distinct().joinToString("\n")
        if (title.isEmpty() && text.isEmpty()) return
        if (isSecurityOrOtp("$title\n$text")) return

        val id = sha256("${sbn.packageName}|${sbn.postTime}|$title|$text")
        val item = org.json.JSONObject()
            .put("id", id)
            .put("packageName", sbn.packageName)
            .put("title", title.take(300))
            .put("text", text.take(1500))
            .put("postedAt", sbn.postTime)
        val inserted = BankNotificationStore.enqueue(this, item)
        if (inserted) {
            BankNotificationStore.recordDiagnostic(
                this,
                "last_queued_at",
                System.currentTimeMillis(),
            )
        }
        if (
            inserted ||
            (recoverExisting && BankNotificationStore.containsPending(this, id))
        ) {
            val shown = BankTransactionNotificationPresenter.show(this, id)
            Log.i(logTag, "Queued bank notification; confirmation shown=$shown")
            BankNotificationStore.recordDiagnostic(
                this,
                "last_confirmation_requested_at",
                System.currentTimeMillis(),
            )
            BankNotificationStore.recordDiagnostic(
                this,
                "last_confirmation_requested_status",
                if (shown) "shown" else "failed",
            )
        }
    }

    private fun sha256(value: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray())
            .joinToString("") { "%02x".format(it) }

    private fun redact(value: String): String =
        Regex(
            """(?i)((?:tk|tài khoản|tai khoan|account|card|thẻ|the)\s*[:\-]?\s*)(\d{8,19})""",
        ).replace(value) { match ->
            "${match.groupValues[1]}***${match.groupValues[2].takeLast(4)}"
        }

    private fun isSecurityOrOtp(value: String): Boolean {
        val normalized = value.lowercase()
        return listOf(
            "otp",
            "one-time password",
            "verification code",
            "mã xác thực",
            "ma xac thuc",
            "mã đăng nhập",
            "ma dang nhap",
            "đổi mật khẩu",
            "doi mat khau",
            "password reset",
        ).any(normalized::contains)
    }

    companion object {
        private const val logTag = "FinFlowBankImport"
        private const val activeRecoveryWindowMillis = 12L * 60L * 60L * 1000L

        fun requestSystemRebind(context: android.content.Context) {
            requestRebind(
                ComponentName(context, BankNotificationListenerService::class.java),
            )
        }
    }
}
