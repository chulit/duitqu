# 11 — Redesign UI/UX modern

**Status:** claimed
**Labels:** ready-for-agent
**Blocks:** —
**Tipe:** feat (UI overhaul)

## Masalah
Desain UI saat ini dinilai jelek oleh pengguna (verifikasi visual 2026-10-15):
tampilan datar seperti spreadsheet, hierarki lemah, tidak ada ikon kategori,
tidak ada navigasi antar-bagian (akun & kategori bahkan belum punya UI).

## Keputusan desain (disetujui pengguna 2026-10-15: "bikin UI yang bagus,
UX yang memudahkan, yang modern")
- Bottom navigation 4 tab: **Beranda, Statistik, Akun, Lainnya**.
- Beranda: hero kartu total saldo + ringkasan bulan + daftar transaksi
  dikelompokkan per tanggal dengan ikon kategori.
- Statistik: bar pemasukan vs pengeluaran + top kategori per bulan.
- Akun: daftar kartu saldo + tambah/ubah akun (UI baru).
- Lainnya: kelola kategori + backup CSV + tentang.
- Sheet tambah transaksi: input nominal besar di atas, grid kategori
  berikon (4 kolom), selektor akun, bagian item tetap ada.
- Tema: light warm-paper + dark slate yang rapi; radius 16–20 konsisten;
  ikon kategori dari Material Icons (mapping nama ikon bawaan).
- Tetap: semua string via AppLocalizations (ID/EN), warna income/expense
  yang sudah ada, keys widget untuk test tidak berubah.

## Kriteria selesai
- [ ] Bottom nav 4 tab berfungsi; FAB tambah tetap ada.
- [ ] Beranda: hero saldo total, ringkasan bulan, transaksi per tanggal + ikon.
- [ ] Statistik: ringkasan + breakdown kategori per bulan.
- [ ] Akun: CRUD akun via UI.
- [ ] Lainnya: daftar kategori + backup + tentang.
- [ ] Sheet tambah: nominal besar, grid kategori ikon, keys test dipertahankan
      (amountField, saveButton, addItemButton, itemName_/itemPrice_/itemQty_,
      fromAccountDropdown, toAccountDropdown, feeField).
- [ ] `flutter analyze` bersih, `flutter test` hijau.
- [ ] Satu commit conventional Indonesia; push ke main (picu rilis otomatis).

## Catatan
- Verifikasi visual akhir tetap oleh pengguna di HP.
