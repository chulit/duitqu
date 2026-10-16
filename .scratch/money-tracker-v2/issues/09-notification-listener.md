# 09: Android notification listener

**What to build:** `NotificationListenerService` native Android → Flutter via
platform channel. Hanya membaca notifikasi dari aplikasi yang diizinkan pengguna,
dengan alur izin yang jelas dan status layanan terpantau.

**Blocked by:** 01 (Fondasi kandidat), 04 (Policy engine).

**Status:** done (2026-10-16)

- [ ] Native `NotificationListenerService` + platform channel ke Flutter
- [ ] Setup flow: penjelasan data → pilih aplikasi sumber → arahkan ke pengaturan Notification Access → mapping akun default → kebijakan penyimpanan → uji contoh notifikasi
- [ ] Izin opt-in eksplisit; bisa dinonaktifkan dan dicabut kapan saja
- [ ] Perubahan izin terdeteksi dan dijelaskan ke pengguna
- [ ] Batasan platform dikomunikasikan jujur (tidak semua notifikasi bisa diproses)
- [ ] Integration test: event notifikasi → kandidat tersimpan lokal
