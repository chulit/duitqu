# Tiket 13 — Cloud Sync (E2EE backup via Google Drive)

Status: DRAFT — disetujui user 2026-10-15 ("Lanjut yg cloud sync dulu deh", scope A + Google Drive).

## Keputusan desain (ADR 0004)
- Scope A: backup terenkripsi end-to-end, BUKAN sync multi-device realtime.
- Payload: CSV dari BackupService (sudah mencakup akun, kategori, transaksi, item).
- Enkripsi: AES-256-GCM; kunci dari passphrase user via PBKDF2 (salt acak per backup).
- Format blob: `DQSYNC1 | salt(16) | nonce(12) | ciphertext | tag(16)` — magic header untuk validasi.
- Passphrase TIDAK PERNAH disimpan; salah passphrase = decrypt gagal dengan pesan jelas.
- Storage: Google Drive `appDataFolder` (scope `drive.appdata`) — user tidak melihat file di Drive biasa.
- Backend pluggable: `SyncBackend` interface; implementasi pertama `DriveSyncBackend`. VPS Oracle bisa jadi backend kedua nanti.
- Privasi: yang keluar dari HP hanya ciphertext. Google tidak bisa membaca isi.

## AC
1. Pengaturan → Backup & Sinkronisasi: seksi "Sinkronisasi Cloud".
2. Hubungkan Google (OAuth, scope drive.appdata saja) / Putuskan.
3. "Backup Sekarang": minta passphrase (min 8 char, konfirmasi) → enkripsi CSV → upload ke appDataFolder sebagai `duitqu-backup-<timestamp>.dqsync`. Tampilkan waktu backup terakhir.
4. "Pulihkan": list backup di cloud (tanggal + ukuran) → minta passphrase → decrypt → impor via BackupService (aditif, tidak menimpa data).
5. Passphrase salah → error jelas, tidak crash.
6. Tanpa koneksi → pesan offline yang jelas.
7. Test: round-trip enkripsi, tamper detection (ciphertext diubah → gagal), passphrase salah → gagal, header invalid → gagal.

## Bukan scope tiket ini
- Sync otomatis/periodik, multi-device realtime, conflict resolution (scope B — tiket terpisah).
- Backend VPS Oracle.

## Aturan main (tetap berlaku)
- Satu commit konvensional Indonesia per tiket.
- `flutter test` + `flutter analyze` bersih di VM Linux.
- Tidak ada nilai finansial yang difabrikasi.
- Push ke main = rilis otomatis (pipeline armed) — minta konfirmasi user sebelum push.
