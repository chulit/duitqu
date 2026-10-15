# 06: Transfer antar akun + biaya admin

**What to build:** Transfer sebagai tipe transaksi tersendiri (bukan
pengeluaran): pilih akun sumber → akun tujuan + nominal. Field biaya admin
opsional — bila diisi, otomatis tercatat sebagai pengeluaran kategori
"Biaya Admin" dari akun sumber. Transfer dikecualikan dari ringkasan belanja.

**Blocked by:** 02 (butuh akun).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan:
- `TransferService` (domain, pure Dart): `saveTransfer(transfer, {fee})` —
  transfer tersimpan sebagai tipe tersendiri (bukan pengeluaran); fee > 0
  otomatis mencatat expense "Biaya Admin" pada akun sumber; fee hanya dibuat
  saat tambah baru (edit tidak duplikat); validasi fee >= 0.
- UI: field "Biaya admin (opsional)" di mode transfer (sembunyi saat edit),
  dengan helper text yang menjelaskan perilaku otomatisnya.
- Saldo: sumber −= amount+fee, tujuan += amount (terverifikasi via
  `AccountRepository.balance`).
- Test: 7 unit test service + 1 widget test (transfer Rp 100.000 + fee
  Rp 2.500 → riwayat menampilkan keduanya).
- `flutter test`: 45/45 hijau. `flutter analyze`: bersih.

- [ ] Transfer memperbarui saldo kedua akun dengan benar
- [ ] Biaya admin (bila diisi) tercatat sebagai pengeluaran "Biaya Admin"
- [ ] Transfer TIDAK muncul di total pengeluaran ringkasan
- [ ] Unit test: saldo, fee, eksklusi dari agregat
