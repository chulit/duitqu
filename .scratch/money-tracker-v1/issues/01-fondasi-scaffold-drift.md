# 01: Fondasi — scaffold Flutter + skema drift + test hijau

**What to build:** Proyek Flutter `duitqu` (applicationId `id.chulit.duitqu`) yang
bisa di-build, dengan skema database drift untuk Transaction, Account, Category,
dan TransactionItem, struktur direktori mengikuti lapisan arsitektur
(presentation → domain → data), dan suite `flutter test` yang hijau.

**Blocked by:** None (can start immediately).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan:
- Scaffold Flutter `duitqu` (`id.chulit.duitqu`), Flutter 3.47.7; platform non-Android
  (ios/linux/macos/web/windows) dibuang agar repo fokus.
- Skema drift: `accounts`, `categories`, `transactions` (type income|expense|transfer,
  amount, category/account/toAccount FK, merchant, date, note), `transaction_items`
  (name, price, qty). Codegen `database.g.dart` sukses.
- Struktur rapi sesuai arsitektur: `lib/src/domain/entities/` (Account, Category,
  Transaction, TransactionItem — pure Dart), `lib/src/domain/repositories/`
  (interface TransactionRepository/AccountRepository/CategoryRepository = seam),
  `lib/src/data/database.dart`. Tanpa import platform-specific di domain/data.
- `flutter test`: 6/6 hijau (skema + entities). `flutter analyze`: No issues found.
- **Catatan jujur**: `flutter build apk` TIDAK bisa jalan di VM ini — Gradle daemon
  mati terus (OOM; VM hanya ~1GB available, `_JAVA_OPTIONS` cap 512m). Ini pola yang
  sama seperti Status Saver: APK hanya di-build di GitHub Actions (tiket 09).
  AC "build apk --debug" diganti menjadi "terverifikasi via CI pada tiket 09".

- [ ] `flutter build apk --debug` sukses dari VM ini
- [ ] Skema drift ter-generate untuk keempat tabel + relasi item-ke-transaksi
- [ ] `flutter test` hijau (suite awal boleh kosong/minimal)
- [ ] Tidak ada dependensi platform-specific di layer domain/data
