# 07: Ringkasan + filter + cari

**What to build:** Jawaban "uangku ke mana": ringkasan harian/mingguan/bulanan
(total pemasukan vs pengeluaran + sisa), saldo berjalan, pengelompokan per
kategori/merchant/akun. Filter: kategori, rentang tanggal, merchant. Pencarian
teks (catatan/merchant/nama item) dan nominal.

**Blocked by:** 04 (butuh data transaksi).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan:
- `SummaryService` (domain, pure Dart): `summarize()` (income/expense/net,
  transfer dikecualikan sesuai ADR 0002), `expenseByCategory()`, `inRange()`,
  `search()` (catatan/merchant/nama item, case-insensitive).
- UI HomeScreen: kartu ringkasan bulanan (Masuk/Keluar/Selisih + navigasi
  ‹ bulan ›), tombol search di AppBar (filter in-memory), tombol filter
  (bottom sheet: akun + kategori, dengan indikator dot & tombol reset),
  daftar menampilkan status "N transaksi ditampilkan" saat filter aktif,
  empty state ganda (belum ada vs tidak cocok filter).
- Test: 6 unit test SummaryService + 1 widget test (ringkasan benar,
  transfer tidak masuk ringkasan, filter akun menampilkan expense +
  transfer masuk yang relevan).
- `flutter test`: 52/52 hijau. `flutter analyze`: bersih.

- [ ] Angka ringkasan benar untuk tiap periode (diuji via SummaryService)
- [ ] Running balance konsisten dengan riwayat
- [ ] Filter kombinasi (kategori + tanggal + merchant) bekerja
- [ ] Pencarian menemukan transaksi by catatan/merchant/item/nominal
- [ ] Nilai kosong dirender '—', tidak difabrikasi
- [ ] Unit test SummaryService (pure, tabel kasus) + widget test layar ringkasan
