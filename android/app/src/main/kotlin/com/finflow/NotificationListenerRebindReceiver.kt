package com.finflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

class NotificationListenerRebindReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (!BankNotificationStore.isEnabled(context)) return
        val accessGranted = NotificationManagerCompat
            .getEnabledListenerPackages(context)
            .contains(context.packageName)
        if (!accessGranted) return
        Log.i(logTag, "Requesting listener rebind after ${intent?.action}")
        BankNotificationListenerService.requestSystemRebind(context)
    }

    companion object {
        private const val logTag = "FinFlowBankImport"
    }
}
