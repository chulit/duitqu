package id.chulit.duitqu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val NOTIFICATION_CHANNEL = "id.chulit.duitqu/notifications"
        const val CONTROL_CHANNEL = "id.chulit.duitqu/notification_control"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Stream notifikasi: native → Dart (tiket 09, spec v2).
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                NotificationEventSink.sink = events
            }

            override fun onCancel(arguments: Any?) {
                NotificationEventSink.sink = null
            }
        })

        // Kontrol: cek izin Notification Access.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONTROL_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> {
                    val enabled = android.provider.Settings.Secure.getString(
                        contentResolver,
                        "enabled_notification_listeners"
                    ) ?: ""
                    result.success(enabled.contains(packageName))
                }
                "openNotificationAccessSettings" -> {
                    try {
                        val intent = android.content.Intent(
                            "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"
                        )
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NO_ACTIVITY", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
