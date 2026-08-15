package com.finflow

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val channelName = "com.finflow/bank_notifications"
    private val postNotificationsRequestCode = 7102
    private var postNotificationsResult: MethodChannel.Result? = null
    private var launchNotificationId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureNotificationIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Create the channel while the app is in the foreground. Some OEM
        // Android builds delay or suppress a first channel created from the
        // notification-listener process while the app is backgrounded.
        BankTransactionNotificationPresenter.ensureChannel(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> result.success(hasNotificationAccess())
                "getImportConfiguration" ->
                    result.success(BankNotificationStore.configuration(this))
                "getImportDiagnostics" ->
                    result.success(BankNotificationStore.diagnostics(this))
                "consumeLaunchNotificationId" -> {
                    result.success(launchNotificationId)
                    launchNotificationId = null
                }
                "requestNotificationListenerRebind" -> {
                    requestNotificationListenerRebind()
                    result.success(hasNotificationAccess())
                }
                "openNotificationAccessSettings" -> {
                    openNotificationAccessSettings()
                    result.success(null)
                }
                "requestPostNotifications" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else if (postNotificationsResult != null) {
                            result.error(
                                "permission_request_in_progress",
                                "Notification permission is already being requested",
                                null,
                            )
                        } else {
                            postNotificationsResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                postNotificationsRequestCode,
                            )
                        }
                    } else {
                        result.success(true)
                    }
                }
                "areAppNotificationsEnabled" ->
                    result.success(BankTransactionNotificationPresenter.areEnabled(this))
                "openAppNotificationSettings" -> {
                    openAppNotificationSettings()
                    result.success(null)
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(null)
                }
                "setImportEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    BankNotificationStore.setEnabled(this, enabled)
                    if (enabled) {
                        BankTransactionNotificationPresenter.ensureChannel(this)
                        requestNotificationListenerRebind()
                    }
                    result.success(null)
                }
                "setEnabledPackages" -> {
                    val packages = call.argument<List<String>>("packages").orEmpty().toSet()
                    BankNotificationStore.setEnabledPackages(this, packages)
                    requestNotificationListenerRebind()
                    result.success(null)
                }
                "getPendingNotifications" ->
                    result.success(BankNotificationStore.pending(this))
                "enqueueTestNotification" -> {
                    val now = System.currentTimeMillis()
                    val sourcePackage = call.argument<String>("packageName") ?: "com.VCB"
                    val id = "debug-$now"
                    BankNotificationStore.enqueue(
                        this,
                        JSONObject()
                            .put("id", id)
                            .put("packageName", sourcePackage)
                            .put("title", "Giao dịch ngân hàng thử nghiệm")
                            .put(
                                "text",
                                "Tài khoản ***1234 vừa ghi nợ 125.000 VND. " +
                                    "Nội dung: Thanh toán cà phê",
                            )
                            .put("postedAt", now),
                    )
                    result.success(BankTransactionNotificationPresenter.show(this, id))
                }
                "acknowledgeNotification" -> {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        BankNotificationStore.remove(this, id)
                        BankTransactionNotificationPresenter.cancel(this, id)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasNotificationAccess(): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)

    private fun requestNotificationListenerRebind() {
        if (!hasNotificationAccess()) return
        BankNotificationListenerService.requestSystemRebind(this)
        BankNotificationStore.recordDiagnostic(
            this,
            "manual_rebind_requested_at",
            System.currentTimeMillis(),
        )
    }

    private fun captureNotificationIntent(intent: Intent?) {
        val id = intent?.getStringExtra(
            BankTransactionNotificationPresenter.notificationIdExtra,
        )
        if (!id.isNullOrBlank()) launchNotificationId = id
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != postNotificationsRequestCode) return
        postNotificationsResult?.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
        )
        postNotificationsResult = null
    }

    private fun openNotificationAccessSettings() {
        val detailIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    ComponentName(this@MainActivity, BankNotificationListenerService::class.java)
                        .flattenToString(),
                )
            }
        } else null
        try {
            startActivity(detailIntent ?: Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
    }

    private fun openAppNotificationSettings() {
        BankTransactionNotificationPresenter.ensureChannel(this)
        val notificationIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                putExtra(
                    Settings.EXTRA_CHANNEL_ID,
                    BankTransactionNotificationPresenter.channelId,
                )
            }
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        }
        try {
            startActivity(notificationIntent)
        } catch (_: Exception) {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                ),
            )
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        } catch (_: Exception) {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                ),
            )
        }
    }
}
