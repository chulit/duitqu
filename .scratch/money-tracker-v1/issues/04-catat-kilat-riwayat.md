# 04: Catat kilat + riwayat transaksi

**What to build:** Alur utama aplikasi: tambah pemasukan/pengeluaran maksimal
2 tap dari layar utama. Form memakai default cerdas (akun & kategori terakhir
dipakai, tanggal = hari ini). Field: nominal, tipe, kategori, akun, tanggal,
catatan opsional, merchant (teks + saran otomatis dari riwayat). Riwayat
kronologis (terbaru dulu), bisa edit, hapus dengan konfirmasi.

**Blocked by:** 01, 02, 03 (butuh akun & kategori).

**Status:** ready-for-agent

- [ ] Tambah transaksi selesai ≤ 2 tap dari home (terverifikasi manual)
- [ ] Default cerdas: akun/kategori terakhir, tanggal hari ini
- [ ] Merchant: ketik bebas + saran dari yang pernah dipakai
- [ ] Riwayat urut waktu terbaru-dulu; edit tersimpan; hapus minta konfirmasi
- [ ] Nominal diformat Rupiah benar; angka tabular
- [ ] Unit test TransactionRepository (termasuk query/filter) + widget test alur tambah
