# 08: Backup CSV — ekspor/impor

**What to build:** Ekspor seluruh data (transaksi + item + akun + kategori) ke
satu file CSV. Impor kembali: validasi dulu, tulis kemudian — baris rusak
dilewati dan dilaporkan per baris (jumlah + alasan), tidak pernah setengah-tulis
dan tidak merusak data yang sudah ada.

**Blocked by:** 04 (butuh model data transaksi).

**Status:** ready-for-agent

- [ ] Ekspor lengkap: semua kolom, semua baris, satu file
- [ ] Impor: laporan {berhasil, dilewati: [baris + alasan]}
- [ ] File tidak valid → tidak ada yang ditulis sama sekali
- [ ] Data yang sudah ada tidak tertimpa/rusak oleh impor
- [ ] Unit test BackupService hijau (termasuk kasus baris rusak)
