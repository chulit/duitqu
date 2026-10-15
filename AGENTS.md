# AGENTS.md

## Agent skills

### Issue tracker

Issues dan spec tinggal sebagai file markdown lokal di `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Lima peran kanonis dipakai apa adanya (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Layout single-context: satu `GLOSSARY.md` + `docs/adr/` di root repo. See `docs/agents/domain.md`.

## Konfigurasi agen (.agents/)

- `workflows/` — alur kerja multi-langkah yang dipakai ulang (lihat `mattpocock-chain.md` untuk rantai fitur baru)
- `rules/` — aturan proyek yang selalu berlaku; baca sebelum menulis kode
- `skills/` — skill lokal khusus proyek ini (ikut ke-version dengan repo)
- `plugins/` — plugin editor/agen yang dipakai proyek ini

See `.agents/README.md`.
