# E2EE cloud backup via Google Drive appDataFolder

Keputusan 2026-10-15: cloud sync v1.x diimplementasikan sebagai **backup
terenkripsi end-to-end** (scope A), bukan sinkronisasi multi-device realtime.

**Considered Options**:
- (B) Sync multi-device penuh dengan conflict resolution (CRDT / last-write-wins
  per record) — ditolak untuk tahap ini: kompleksitas tinggi, risiko data loss
  pada merge, belum ada kebutuhan multi-device aktif.
- Backend VPS Oracle self-hosted — ditunda: signup Oracle masih pause; dijadikan
  backend kedua via interface pluggable.
- Supabase/Firebase — ditolak: vendor lock-in; E2EE tetap wajib di atasnya,
  jadi tidak ada keunggulan dibanding Drive untuk scope A.

**Alasan**: janji privasi ADR 0001 ("datamu tidak keluar dari HP") dipertahankan
dengan enkripsi di sisi klien — yang diupload hanya ciphertext AES-256-GCM.
Google Drive `appDataFolder` dipilih karena gratis, tanpa server untuk
di-maintain, dan file tidak terlihat di Drive user (scope `drive.appdata` saja,
prinsip least-privilege). Payload memakai CSV BackupService yang sudah ada
(aditif saat impor — data lokal tidak pernah ditimpa).

Kunci enkripsi diturunkan dari passphrase user (PBKDF2, salt acak per backup);
passphrase tidak pernah disimpan di mana pun. Lupa passphrase = backup tidak
bisa dibuka — ini konsekuensi yang dikomunikasikan jelas di UI.

**Consequences**:
- Interface `SyncBackend` memisahkan storage dari enkripsi; menambah backend
  (VPS) tidak mengubah format blob.
- Format blob berversi (`DQSYNC1` header) agar bisa berevolusi.
- Restore bersifat aditif mengikuti semantik BackupService.
- Scope B (multi-device realtime) menjadi ADR/tiket terpisah bila dibutuhkan.
