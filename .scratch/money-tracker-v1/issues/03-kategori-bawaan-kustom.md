# 03: Kategori — bawaan + kustom

**What to build:** 12 kategori bawaan di-seed sekali saat pertama jalan
(Makan & Minum, Transport, Belanja, Tagihan, Pulsa & Internet, Kesehatan,
Hiburan, Pendidikan, Gaji, Bonus, Biaya Admin, Lainnya); pengguna bisa tambah
kategori sendiri dan menghapus kategori yang tidak dipakai transaksi.

**Blocked by:** 01 (butuh skema + fondasi).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan:
- `DriftCategoryRepository` + daftar `defaultCategories` (12 kategori sesuai
  persetujuan grill: Makan & Minum … Biaya Admin … Lainnya; ikon gaya Lucide).
- `seedDefaults()` idempoten — aman dipanggil tiap app start, tidak duplikat.
- Kategori bawaan read-only: hapus/ubah ditolak (StateError Bahasa Indonesia).
- Kategori kustom: tambah/ubah/hapus; hapus ditolak bila masih dipakai transaksi.
- 8 unit test (drift in-memory asli): seed 12, idempotensi, urutan/nama,
  CRUD kustom, proteksi bawaan, proteksi kategori terpakai.
- `flutter test`: 23/23 hijau. `flutter analyze`: bersih.

- [ ] Kategori bawaan muncul tepat sekali (tidak duplikat saat restart)
- [ ] Tambah kategori kustom (nama + ikon + warna)
- [ ] Hapus kategori yang dipakai transaksi DITOLAK dengan pesan jelas
- [ ] Unit test CategoryRepository hijau via `flutter test`
