package id.chulit.duitqu

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

/**
 * Meneruskan notifikasi Android ke Flutter via EventChannel (tiket 09, spec v2).
 *
 * Hanya meneruskan; tidak menyimpan atau memproses. Pemfilteran aplikasi
 * (allowlist) dilakukan di sisi Dart agar mudah diubah user tanpa
 * deploy ulang native.
 *
 * Privasi: konten notifikasi hanya diteruskan saat layanan aktif dan
 * izin Notification Access diberikan user secara eksplisit.
 */
class DuitQuNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        val extras = notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        // Abaikan notifikasi kosong dan notifikasi DuitQu sendiri.
        if (title.isBlank() && text.isBlank()) return
        if (sbn.packageName == packageName) return

        val payload = mapOf(
            "packageName" to sbn.packageName,
            "title" to title,
            "text" to text,
            "postedAt" to sbn.postTime,
            "id" to sbn.id.toString(),
            "tag" to (sbn.tag ?: ""),
        )
        NotificationEventSink.send(payload)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Tidak perlu aksi — kandidat sudah tersimpan saat posted.
    }
}

/**
 * Jembatan EventChannel: native → Dart.
 * Diisi oleh MainActivity saat channel dibuat.
 */
object NotificationEventSink {
    var sink: EventChannel.EventSink? = null

    fun send(payload: Map<String, Any>) {
        // Kirim di main thread agar aman untuk EventChannel.
        sink?.let {
            try {
                it.success(payload)
            } catch (_: Exception) {
                // Sink mati (Dart tidak listen) — abaikan.
            }
        }
    }
}
