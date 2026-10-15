# 05: Line item (struk) per transaksi

**What to build:** Satu transaksi belanja bisa dipecah menjadi item-item produk
(nama + harga + qty, mis. belanja Indomaret: banyak produk). Total transaksi
terhitung otomatis dari item. Item opsional — transaksi tanpa item tetap valid
dengan nominal manual.

**Blocked by:** 04 (butuh alur catat transaksi).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan (backend item sudah ada di tiket 04):
- Editor rincian item di `AddTransactionSheet` (non-transfer): tambah/hapus
  baris item (nama, harga, qty), baris kosong dilewati, validasi per baris
  dengan pesan Bahasa Indonesia.
- Total otomatis: saat ada item, field nominal jadi read-only dan mengikuti
  jumlah item; tersimpan konsisten via invariant repository.
- Edit mode: item lama terisi kembali, bisa diubah/dihapus.
- Riwayat menampilkan "N item" di subtitle.
- Widget test baru: catat dengan 2 item → total otomatis Rp 12.000 tampil di
  sheet & riwayat, konsisten dengan backend.
- `flutter test`: 37/37 hijau. `flutter analyze`: bersih.

- [ ] Tambah/edit/hapus item di dalam transaksi
- [ ] Total otomatis = sum(harga × qty); invariant dijaga repository
      (amount == sum bila item ada)
- [ ] Transaksi tanpa item tetap bisa disimpan (nominal manual)
- [ ] Unit test invariant + widget test editor item
