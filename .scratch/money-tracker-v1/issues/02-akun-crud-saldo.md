# 02: Akun — CRUD + saldo per akun

**What to build:** Pengguna bisa mendaftarkan akun-akunnya (tipe: bank, cash,
e-wallet, lain-lain) dengan saldo awal yang diisi manual (default Rp0), melihat
daftar akun beserta saldonya yang terhitung otomatis, mengubah, dan menghapus
akun.

**Blocked by:** 01 (butuh skema + fondasi).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan:
- `DriftAccountRepository` (adapter drift untuk seam `AccountRepository`):
  save insert/update, delete menolak bila akun masih punya transaksi
  (StateError berbahasa Indonesia, bukan silent), list terurut,
  `balance()` = initialBalance + income − expense ± transfer (transfer keluar
  mengurangi sumber, menambah tujuan), dengan filter `upTo` opsional.
- Test memakai database drift asli in-memory (`NativeDatabase.memory()` —
  `libsqlite3` tersedia di VM): 9 test (CRUD, default saldo 0, update,
  proteksi hapus termasuk akun tujuan transfer, aritmetika saldo, upTo,
  akun tidak ada).
- `flutter test`: 15/15 hijau (termasuk tiket 01). `flutter analyze`: bersih.

- [ ] Tambah akun: nama, tipe, saldo awal manual (default 0)
- [ ] Daftar akun menampilkan saldo = saldo awal + pemasukan − pengeluaran ± transfer
- [ ] Edit akun bisa; hapus akun yang masih punya transaksi DITOLAK dengan pesan jelas (bukan silent)
- [ ] Unit test AccountRepository hijau via `flutter test` (in-memory, tanpa emulator)
