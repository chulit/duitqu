# Mattpocock Chain

Rantai kerja standar untuk fitur baru di proyek ini, mengikuti skill
mattpocock yang terinstall.

## Trigger

Pengguna meminta fitur baru, atau spec di `.scratch/` berstatus `needs-info`
sudah dilengkapi.

## Langkah

1. **Setup** (sekali per repo) — pastikan `AGENTS.md` + `docs/agents/` ada.
   Sudah selesai untuk repo ini.
2. **to-spec** — sintesis diskusi jadi `.scratch/<fitur>/spec.md`.
   Jangan interview; tulis asumsi eksplisit di Further Notes bila diskusi tipis.
3. **Review spec** — pengguna koreksi; perbaiki sampai ia bilang oke.
   Spec belum boleh lanjut sebelum review ini.
4. **to-tickets** — pecah spec jadi tiket `01..NN` di
   `.scratch/<fitur>/issues/`, lengkap dengan blocking edges.
5. **implement** — kerjakan per tiket sesuai urutan blocking.

## Selesai

Semua tiket `resolved`, spec berstatus `ready-for-agent` → `done`,
dan ada commit per tiket.
