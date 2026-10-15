# 01: Fondasi — scaffold Flutter + skema drift + test hijau

**What to build:** Proyek Flutter `duitqu` (applicationId `id.chulit.duitqu`) yang
bisa di-build, dengan skema database drift untuk Transaction, Account, Category,
dan TransactionItem, struktur direktori mengikuti lapisan arsitektur
(presentation → domain → data), dan suite `flutter test` yang hijau.

**Blocked by:** None (can start immediately).

**Status:** claimed

- [ ] `flutter build apk --debug` sukses dari VM ini
- [ ] Skema drift ter-generate untuk keempat tabel + relasi item-ke-transaksi
- [ ] `flutter test` hijau (suite awal boleh kosong/minimal)
- [ ] Tidak ada dependensi platform-specific di layer domain/data
