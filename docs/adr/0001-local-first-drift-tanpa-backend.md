# SQLite via drift, tanpa backend — local-first penuh

Aplikasi menyimpan seluruh data di SQLite lokal via `drift`. Tidak ada akun
pengguna, tidak ada backend, tidak ada analytics, tidak ada crash reporter.

**Considered Options**: Firebase (Firestore + Auth) — default umum aplikasi
Flutter; Supabase — alternatif backend-as-a-service.

**Alasan**: data keuangan adalah data paling sensitif pengguna; janji "datamu
tidak keluar dari HP" adalah diferensiasi produk (lihat PRD). Tanpa backend =
tanpa biaya server, tanpa ketergantungan jaringan, selaras dengan prinsip
gratis-penuh pengguna. Konsekuensinya (tanpa sinkronisasi multi-device)
diterima dan dicatat sebagai non-fitur v1.

**Consequences**: backup menjadi tanggung jawab aplikasi via ekspor/impor CSV
(lihat BackupService di codebase-design); migrasi skema harus preservasi data
(lihat 14-data-safety). Cloud sync direncanakan untuk v1.x (keputusan
2026-10-15): desainnya harus menjaga janji privasi (enkripsi end-to-end
menjadi kandidat utama) — ADR tersendiri saat waktunya tiba.
