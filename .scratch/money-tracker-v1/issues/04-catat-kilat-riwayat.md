# 04: Catat kilat + riwayat transaksi

**What to build:** Alur utama aplikasi: tambah pemasukan/pengeluaran maksimal
2 tap dari layar utama. Form memakai default cerdas (akun & kategori terakhir
dipakai, tanggal = hari ini). Field: nominal, tipe, kategori, akun, tanggal,
catatan opsional, merchant (teks + saran otomatis dari riwayat). Riwayat
kronologis (terbaru dulu), bisa edit, hapus dengan konfirmasi.

**Blocked by:** 01, 02, 03 (butuh akun & kategori).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan:
- `DriftTransactionRepository`: save (invariant amount==sum(item), validasi
  nominal>0 / item / transfer), delete (transaksi+item satu unit), list dengan
  filter (tipe, akun termasuk toAccount, kategori, merchant, rentang tanggal),
  `search()` (catatan/merchant/nama item), `watch()` reaktif,
  `merchantSuggestions()` unik terbaru-dulu.
- Presentation layer pertama: `DuitQuTheme` (emerald/terakota, angka tabular),
  `formatRupiah`/`formatTanggal`, `QuickAddDefaults` (default cerdas in-memory),
  `HomeScreen` (riwayat kronologis + FAB + hapus dengan konfirmasi + tap untuk
  edit), `AddTransactionSheet` (tipe Keluar/Masuk/Transfer, nominal autofocus,
  chips kategori, dropdown akun ganda untuk transfer, date picker, merchant
  autocomplete, catatan, validasi), `main.dart` wiring + seed kategori.
- Test: 12 unit test repository + 2 widget test (alur catat kilat, hapus
  konfirmasi). Total suite 36/36 hijau. `flutter analyze`: bersih.
- Catatan: `DropdownButtonFormField.value` deprecated di Flutter 3.47 →
  dipakai `initialValue`.

- [ ] Tambah transaksi selesai ≤ 2 tap dari home (terverifikasi manual)
- [ ] Default cerdas: akun/kategori terakhir, tanggal hari ini
- [ ] Merchant: ketik bebas + saran dari yang pernah dipakai
- [ ] Riwayat urut waktu terbaru-dulu; edit tersimpan; hapus minta konfirmasi
- [ ] Nominal diformat Rupiah benar; angka tabular
- [ ] Unit test TransactionRepository (termasuk query/filter) + widget test alur tambah
