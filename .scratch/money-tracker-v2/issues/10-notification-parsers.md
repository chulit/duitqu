# 10: Parser notifikasi deterministik

**What to build:** Parser khusus format notifikasi yang dikenal (contoh: GoPay,
BCA — "Pembayaran Rp28.000 di Kopi Kenangan berhasil" → kandidat expense lengkap
dengan merchant, nominal, akun dari mapping).

**Blocked by:** 09 (Notification listener), 06 (Chat parser — interface parser dipakai ulang).

**Status:** done (2026-10-16)

- [ ] `DeterministicParser` per format sumber yang dikenal dan diuji
- [ ] Ekstraksi: nominal, merchant, timestamp (atau tandai waktu belum terverifikasi), tipe (expense/income/transfer/refund/pending/failed/unknown)
- [ ] Mapping sumber → akun default (dari setup tiket 09)
- [ ] Kategori hasil inferensi tidak dianggap pasti; bisa diubah pengguna
- [ ] Unit test per format: dataset notifikasi contoh
