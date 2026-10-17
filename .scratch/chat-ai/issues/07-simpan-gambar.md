# 07: Simpan gambar struk

**What to build:** Gambar struk hasil scan/kamera disimpan ke app-private storage (`receipts/`), path-nya disimpan di transaksi (field baru `receiptImagePath`), bisa dibuka dari halaman detail transaksi.

**Blocked by:** 04 (kamera scan).

**Status:** ready-for-agent

- [ ] Field `receiptImagePath` di entity + migrasi drift
- [ ] Gambar disimpan ke app-private storage saat transaksi disimpan
- [ ] Detail transaksi menampilkan thumbnail + buka gambar penuh
- [ ] Test: simpan dengan gambar → path tersimpan → tampil di detail
