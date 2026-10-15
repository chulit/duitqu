# 09: Polish — tema gelap, lokalisasi, ikon

**What to build:** Penyelesaian akhir v1: mode gelap yang benar (bukan sekadar
invert), lokalisasi penuh Bahasa Indonesia + Bahasa Inggris (tanpa string
hardcode), ikon launcher DuitQu terpasang sebagai adaptive icon, nama aplikasi
final di semua tempat, format Rupiah + angka tabular konsisten.

**Blocked by:** 04, 05, 06, 07, 08 (polish setelah semua fitur).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan:
- **Lokalisasi ID/EN penuh** (`AppLocalizations`, hand-rolled tanpa codegen):
  ~70 string UI lewat `AppLocalizations.of(context)` — tidak ada lagi string
  hardcode di layar (home, tambah transaksi, backup). Bahasa ikut perangkat
  (id/en), default Indonesia. Nama bulan, alasan baris impor rusak (via kode
  error di `BackupService`), dan pesan `BackupFormatException` ikut lokal.
- **Dark theme benar**: `ColorScheme.fromSeed` brightness dark (bukan invert);
  warna nominal income/expense pakai varian terang di mode gelap
  (`incomeColor`/`expenseColor`) agar kontras; angka tetap tabular.
- **Ikon launcher adaptif**: foreground vector koin buku-kas (krim di atas
  transparan) + background emerald `#004E3C`; `mipmap-anydpi-v26`
  (icon + round). minSdk naik ke 26 (Android 8.0+) — tanpa PNG legacy.
  Pelajaran: `push_files` menulis biner sebagai teks (file korup) — biner
  jangan lewat situ; vector drawable jadi solusi rapi.
- **Nama aplikasi**: `android:label="DuitQu"`; title bar & MaterialApp konsisten.
- 9 unit test lokalisasi baru; full suite 67/67 hijau, analyze bersih.

Catatan: verifikasi visual di HP tetap oleh pengguna (AC terakhir tiket).

- [ ] Dark theme: semua layar terbaca, kontras cukup, tidak ada teks hilang
- [ ] Tidak ada string UI hardcode (semua lewat sistem lokalisasi, EN+ID)
- [ ] Ikon launcher terpasang (adaptive icon, masuk safe zone)
- [ ] "DuitQu" tampil konsisten (app name, title bar)
- [ ] Verifikasi visual di HP oleh pengguna sebelum dianggap selesai
