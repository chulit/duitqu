# 03: Kategori — bawaan + kustom

**What to build:** 12 kategori bawaan di-seed sekali saat pertama jalan
(Makan & Minum, Transport, Belanja, Tagihan, Pulsa & Internet, Kesehatan,
Hiburan, Pendidikan, Gaji, Bonus, Biaya Admin, Lainnya); pengguna bisa tambah
kategori sendiri dan menghapus kategori yang tidak dipakai transaksi.

**Blocked by:** 01 (butuh skema + fondasi).

**Status:** ready-for-agent

- [ ] Kategori bawaan muncul tepat sekali (tidak duplikat saat restart)
- [ ] Tambah kategori kustom (nama + ikon + warna)
- [ ] Hapus kategori yang dipakai transaksi DITOLAK dengan pesan jelas
- [ ] Unit test CategoryRepository hijau via `flutter test`
