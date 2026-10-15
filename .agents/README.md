# .agents/

Konfigurasi agen untuk proyek money-tracker. Semua yang ada di sini dibaca oleh
agen (Muse maupun agen lain yang dipakai di repo ini) sebelum mulai kerja.

```
.agents/
├── workflows/   # Alur kerja multi-langkah yang dipakai ulang
├── rules/       # Aturan proyek yang selalu berlaku
├── skills/      # Skill lokal khusus proyek ini
└── plugins/     # Plugin editor/agen yang dipakai proyek ini
```

Berkaitan dengan:
- `AGENTS.md` di root — konfigurasi skill engineering (issue tracker, triage, domain docs)
- `docs/agents/` — detail konfigurasi skill mattpocock
