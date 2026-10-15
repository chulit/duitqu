# Workflows

Alur kerja multi-langkah yang dipakai ulang di proyek ini. Satu workflow = satu
file markdown.

## Konvensi

- Nama file: `<nama-workflow>.md` (kebab-case), mis. `mattpocock-chain.md`
- Isi tiap workflow: **Trigger** (kapan dipakai), **Langkah** (urutan kerja),
  **Selesai** (kriteria done)
- Workflow boleh memanggil skill di `../skills/` atau skill global

## Daftar

- `mattpocock-chain.md` — rantai setup → to-spec → to-tickets → implement
  untuk fitur baru
- `commit.md` — konvensi commit & verifikasi pra-commit (Husky enforcement);
  hanya jalan saat user eksplisit meminta commit
