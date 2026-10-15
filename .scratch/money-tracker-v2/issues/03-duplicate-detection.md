# 03: Duplicate detection + idempotent save

**What to build:** Satu event yang diproses dua kali tidak boleh menghasilkan dua
transaksi. Fingerprint kandidat ternormalisasi + unique constraint di database.

**Blocked by:** 01 (Fondasi kandidat).

**Status:** done (2026-10-16)

- [ ] `DuplicateDetector`: fingerprint dari source app + reference ID + nominal + tipe + kedekatan waktu + merchant
- [ ] Reference ID sama dari sumber sama → tidak ada transaksi baru (status duplicate)
- [ ] Dua pembelian mirip tapi beda waktu → tetap dua transaksi berbeda
- [ ] Unique constraint untuk idempotency; pemrosesan ulang tidak menambah record
- [ ] Unit test: semua skenario §7 dan §12 spec
