# 12: Quality hardening v2

**What to build:** Evaluasi akurasi parser, benchmark performa, privacy review,
dan financial correctness tests sebagai Definition of Done v2.

**Blocked by:** 06 (Chat parser), 10 (Notification parsers).

**Status:** done (2026-10-16)

- [ ] Dataset uji parser + evaluasi akurasi; threshold confidence dari data
- [ ] Benchmark: p95 pemrosesan notifikasi sederhana < 2 detik; UI tetap responsif
- [ ] Privacy review: raw payload tidak disimpan permanen; tidak ada isi notifikasi di log
- [ ] Financial correctness tests: transfer/ refund/pending/undo konsisten (§12 spec)
- [ ] Dokumentasi konfigurasi platform (izin, batasan)
