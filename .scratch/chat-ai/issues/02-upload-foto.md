# 02: Upload foto struk dari galeri

**What to build:** Dari menu lampiran, pilih "Upload foto" → buka galeri → pilih foto struk → ML Kit membaca → kartu konfirmasi muncul di chat (seperti hasil scan kamera).

**Blocked by:** 01 (menu lampiran).

**Status:** ready-for-agent

- [ ] Image picker galeri terbuka dari menu lampiran
- [ ] Foto terpilih diproses ML Kit (reuse ReceiptScanService)
- [ ] Kartu konfirmasi muncul di chat dengan merchant/nominal/tanggal
- [ ] Smart defaults berlaku (kategori, akun)
- [ ] Test: flow upload → konfirmasi
