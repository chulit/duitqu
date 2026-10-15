# 05: Line item (struk) per transaksi

**What to build:** Satu transaksi belanja bisa dipecah menjadi item-item produk
(nama + harga + qty, mis. belanja Indomaret: banyak produk). Total transaksi
terhitung otomatis dari item. Item opsional — transaksi tanpa item tetap valid
dengan nominal manual.

**Blocked by:** 04 (butuh alur catat transaksi).

**Status:** ready-for-agent

- [ ] Tambah/edit/hapus item di dalam transaksi
- [ ] Total otomatis = sum(harga × qty); invariant dijaga repository
      (amount == sum bila item ada)
- [ ] Transaksi tanpa item tetap bisa disimpan (nominal manual)
- [ ] Unit test invariant + widget test editor item
