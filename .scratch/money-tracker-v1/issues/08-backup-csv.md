# 08: Backup CSV — ekspor/impor

**What to build:** Ekspor seluruh data (transaksi + item + akun + kategori) ke
satu file CSV. Impor kembali: validasi dulu, tulis kemudian — baris rusak
dilewati dan dilaporkan per baris (jumlah + alasan), tidak pernah setengah-tulis
dan tidak merusak data yang sudah ada.

**Blocked by:** 04 (butuh model data transaksi).

**Status:** resolved

## Answer

Selesai 2026-10-15. Yang dikerjakan:
- `BackupService` (data layer): ekspor satu CSV (tag `duitqu-backup-v1`, header
  18 kolom, record account/category/transaction/item); impor validasi-dulu
  (tag + header cocok, kalau tidak → `BackupFormatException` tanpa tulis),
  baris rusak dilewati per baris dengan alasan (`SkippedRow`), tulis atomik
  dalam transaksi drift, ID lama dipetakan ke ID baru, data lama tidak
  disentuh, kategori bawaan ditautkan by-name (tidak duplikat).
- UI minimal: tombol Backup di AppBar → bottom sheet Ekspor (share file CSV
  via share_plus) / Impor (pilih file via file_picker, dialog laporan hasil
  + daftar baris dilewati).
- 6 unit test BackupService hijau (round-trip, ID remap, baris rusak, file
  tidak valid) + wiring HomeScreen/main.
- Full suite 58/58 hijau, `flutter analyze` bersih.

Catatan: `file_picker` 13.x API berubah (`FilePicker.pickFiles` → List,
tanpa `.platform`); `share_plus` 13.x pakai `SharePlus.instance.share`
(deprecated static dihindari).

- [ ] Ekspor lengkap: semua kolom, semua baris, satu file
- [ ] Impor: laporan {berhasil, dilewati: [baris + alasan]}
- [ ] File tidak valid → tidak ada yang ditulis sama sekali
- [ ] Data yang sudah ada tidak tertimpa/rusak oleh impor
- [ ] Unit test BackupService hijau (termasuk kasus baris rusak)
