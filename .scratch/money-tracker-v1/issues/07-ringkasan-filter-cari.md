# 07: Ringkasan + filter + cari

**What to build:** Jawaban "uangku ke mana": ringkasan harian/mingguan/bulanan
(total pemasukan vs pengeluaran + sisa), saldo berjalan, pengelompokan per
kategori/merchant/akun. Filter: kategori, rentang tanggal, merchant. Pencarian
teks (catatan/merchant/nama item) dan nominal.

**Blocked by:** 04 (butuh data transaksi).

**Status:** ready-for-agent

- [ ] Angka ringkasan benar untuk tiap periode (diuji via SummaryService)
- [ ] Running balance konsisten dengan riwayat
- [ ] Filter kombinasi (kategori + tanggal + merchant) bekerja
- [ ] Pencarian menemukan transaksi by catatan/merchant/item/nominal
- [ ] Nilai kosong dirender '—', tidak difabrikasi
- [ ] Unit test SummaryService (pure, tabel kasus) + widget test layar ringkasan
