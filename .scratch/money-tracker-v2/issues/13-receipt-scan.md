# 13: Scan struk via kamera (Android)

**What to build:** Foto struk belanja → OCR on-device → kandidat transaksi
otomatis (merchant, nominal, tanggal) → masuk pipeline yang sama
seperti notifikasi (duplikat → policy → inbox/auto-save).

**Blocked by:** 01 (Fondasi kandidat), 04 (Policy engine).

**Status:** done (2026-10-16)

- [ ] Izin kamera runtime (POST_NOTIFICATIONS tidak perlu; CAMERA saja)
- [ ] Ambil foto via `image_picker` atau `camera`
- [ ] OCR on-device via `google_mlkit_text_recognition` (offline, gratis, tanpa server)
- [ ] Parser struk deterministik: total bayar, merchant (baris atas), tanggal
- [ ] Hasil OCR → `TransactionCandidate` (`sourceType: receiptScan`, confidence dari kelengkapan field)
- [ ] Field yang tidak yakin → kandidat `needsReview` dengan alasan jelas
- [ ] Foto struk tidak disimpan permanen setelah OCR (privasi); hanya payload ter-parse
- [ ] Unit test: dataset teks OCR contoh → parse benar

**Catatan:**
- `TransactionOrigin.receiptScan` sudah ada di data model; tinggal dipakai.
- OCR ML Kit butuh model text-recognition yang di-download sekali (~30MB) — komunikasikan ke user saat pertama pakai.
- Struk tulisan tangan / buram → confidence rendah → inbox, bukan auto-save.
