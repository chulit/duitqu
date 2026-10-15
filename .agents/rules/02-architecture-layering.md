# 02 — Architecture Layering

Arsitektur: clean architecture yang disederhanakan untuk aplikasi utilitas
satu fitur (mengikuti pola Status Saver).

## Lapisan (dependency hanya mengarah ke dalam)

```
presentation (UI, tipis — tanpa logika bisnis)
    ↓
domain (entity, repository interface, SummaryService — pure Dart)
    ↓
data (drift/SQLite, implementasi repository, BackupService)
```

## Aturan

- Logika bisnis **dilarang** di widget. Widget hanya render state dan
  meneruskan event.
- Modul domain/data:
  - `TransactionRepository` — CRUD + query/filter transaksi (SEAM UTAMA testing)
  - `CategoryRepository` — kategori bawaan + kustom
  - `SummaryService` — agregasi harian/mingguan/bulanan, running balance
    (pure function, tanpa dependensi framework)
  - `BackupService` — ekspor/impor CSV
- **Dilarang** import platform-specific (`dart:io` yang Android-only,
  MethodChannel, dsb.) di domain/data — iOS harus bisa menyusul tanpa rewrite.
- Persistensi: SQLite via `drift`. Perubahan skema wajib lewat migrasi
  drift yang teruji (lihat `14-data-safety.md`).
- Satu fitur = satu direktori di `.scratch/<fitur>/`; implementasi dipecah
  per tiket dengan blocking edges yang jelas.

## Testing

- Unit test **wajib** untuk setiap modul domain/data baru.
- Test harus hijau via `flutter test` di VM Linux ini — tanpa emulator,
  tanpa HP (repository diuji dengan in-memory SQLite).
- Uji perilaku eksternal, bukan detail implementasi.
