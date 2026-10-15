# 02: Akun — CRUD + saldo per akun

**What to build:** Pengguna bisa mendaftarkan akun-akunnya (tipe: bank, cash,
e-wallet, lain-lain) dengan saldo awal yang diisi manual (default Rp0), melihat
daftar akun beserta saldonya yang terhitung otomatis, mengubah, dan menghapus
akun.

**Blocked by:** 01 (butuh skema + fondasi).

**Status:** ready-for-agent

- [ ] Tambah akun: nama, tipe, saldo awal manual (default 0)
- [ ] Daftar akun menampilkan saldo = saldo awal + pemasukan − pengeluaran ± transfer
- [ ] Edit akun bisa; hapus akun yang masih punya transaksi DITOLAK dengan pesan jelas (bukan silent)
- [ ] Unit test AccountRepository hijau via `flutter test` (in-memory, tanpa emulator)
