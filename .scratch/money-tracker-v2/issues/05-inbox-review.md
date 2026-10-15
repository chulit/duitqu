# 05: Inbox review tersambung ke kandidat

**What to build:** Layar Inbox yang sekarang masih UI kosong disambung ke
`CandidateRepository`: daftar kandidat butuh konfirmasi dengan sumber, ringkasan,
dan alasan review — bisa konfirmasi, edit, abaikan, atau tandai duplikat.

**Blocked by:** 01 (Fondasi kandidat).

**Status:** done (2026-10-16)

- [ ] Inbox menampilkan kandidat `needs_review` dari repository (bukan dummy)
- [ ] Setiap item: sumber input, ringkasan transaksi, status pengenalan, alasan review
- [ ] Aksi: konfirmasi (simpan via TransactionRepository) / edit / abaikan / tandai duplikat
- [ ] Kandidat belum dikonfirmasi TIDAK masuk total pemasukan/pengeluaran
- [ ] Widget test: alur review sampai transaksi tersimpan
