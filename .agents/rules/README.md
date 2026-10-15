# Rules

Aturan proyek yang selalu berlaku, tanpa kecuali. Agen wajib membaca folder ini
sebelum menulis kode.

## Konvensi

- Penomoran mengikuti pola `<NN>-<nama>.md` (dua digit, boleh tidak berurutan —
  nomor adalah identitas stabil, bukan urutan baca)
- Satu aturan = satu file; tiap file: aturan + alasan singkat
- Aturan di sini mengalahkan default skill bila bertentangan; konflik dengan
  ADR dicatat eksplisit (lihat `docs/agents/domain.md`)

## Daftar

- `00-agent-contract.md` — kontrak perilaku agen: bahasa, otoritas kerja,
  larangan bypass hook & commit otomatis, cara melapor
- `02-architecture-layering.md` — clean architecture yang disederhanakan,
  modul, larangan dependensi platform-specific di domain/data, kewajiban unit test
- `05-ui-component-priority.md` — prioritas komponen UI, lokalisasi EN/ID,
  format Rupiah, kejujuran data, 2-tap tambah transaksi
- `06-security-and-errors.md` — 100% offline, tanpa secret di repo,
  error handling berbahasa Indonesia, konfirmasi aksi destruktif
- `14-data-safety.md` — data user sakral: tanpa auto-delete/TTL, migrasi
  preservasi data, impor tervalidasi, tanpa modifikasi angka diam-diam
