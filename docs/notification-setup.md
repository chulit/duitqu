# Konfigurasi Platform — Auto-Catat Notifikasi (v2)

## Izin Android

DuitQu memakai `NotificationListenerService` untuk membaca notifikasi
dari aplikasi yang dipilih pengguna.

| Item | Detail |
|---|---|
| Service | `id.chulit.duitqu.DuitQuNotificationListener` |
| Permission | `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` |
| Channel Dart | EventChannel `id.chulit.duitqu/notifications` |
| Kontrol | MethodChannel `id.chulit.duitqu/notification_control` |

### Alur izin (opt-in eksplisit)

1. Pengguna membuka Profil → Auto-Catat → "Auto-Catat Notifikasi".
2. Layar setup menjelaskan: data apa yang dibaca, hanya aplikasi
   terpilih yang diproses, bisa dicabut kapan saja.
3. Pengguna menekan "Buka Pengaturan" → Android membuka
   `ACTION_NOTIFICATION_LISTENER_SETTINGS`.
4. Pengguna mengaktifkan akses untuk DuitQu secara manual.
5. Pengguna memilih aplikasi sumber (GoPay, BCA, dll) — allowlist
   disimpan di `SharedPreferences` (`notif_allowed_packages`).

### Pencabutan

- Pengguna bisa menonaktifkan akses kapan saja via
  Pengaturan Android → Notifikasi → Akses notifikasi.
- Perubahan izin terdeteksi saat layar setup dibuka ulang
  (status di-refresh dari `isNotificationAccessGranted`).

## Batasan platform (jujur ke pengguna)

- Tidak semua notifikasi bisa diproses: hanya yang mencantumkan
  nominal (format `Rp...`) yang bisa jadi kandidat.
- Notifikasi tanpa nominal → diabaikan, tidak masuk Inbox.
- Format aplikasi yang belum dikenal → parser generik dengan
  confidence rendah → masuk Inbox untuk review manual.
- Notifikasi `failed` / `pending` → kandidat dibuat tapi policy
  mengabaikan (tidak tercatat sebagai transaksi).

## Privasi

- Konten notifikasi **hanya diteruskan** saat layanan aktif dan
  izin diberikan; tidak ada pengiriman ke server mana pun
  (100% lokal, sesuai arsitektur DuitQu).
- Yang disimpan permanen: payload **ter-parse** (tipe, nominal,
  merchant, deskripsi) di tabel `transaction_candidates` —
  bukan notifikasi mentah (extras lengkap tidak disimpan).
- Tidak ada isi notifikasi yang ditulis ke log
  (tidak ada `print`/`debugPrint` di pipeline notifikasi).
- Notifikasi dari aplikasi di luar allowlist **tidak diteruskan**
  ke Dart (difilter di sisi native via package check? tidak —
  difilter di Dart `NotificationBridge`; native meneruskan semua
  kecuali notifikasi DuitQu sendiri, lalu Dart memfilter).
