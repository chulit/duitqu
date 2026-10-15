# 04: Policy engine auto-save vs review

**What to build:** Mesin kebijakan yang memutuskan kandidat auto-save atau masuk
inbox review, plus UI pengaturan kebijakan di Profil.

**Blocked by:** 01 (Fondasi kandidat), 03 (Duplicate detection).

**Status:** done (2026-10-16)

- [ ] `AutoRecordPolicy`: auto-save hanya bila sumber diizinkan, tipe dikenali, nominal valid, akun pasti, bukan duplikat, bukan indikasi gagal/refund/pending, validasi domain lolos
- [ ] Selain itu → `needs_review` dengan review_reason yang jelas
- [ ] Confidence sebagai sinyal kualitas (bukan satu-satunya syarat); threshold via dataset uji
- [ ] UI: pengaturan kebijakan (auto-save / selalu konfirmasi) + penjelasan
- [ ] Unit test: matriks keputusan auto-save vs review vs ignore
