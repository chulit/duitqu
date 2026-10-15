---
description: Mengelompokkan, memverifikasi, dan membuat commit perubahan secara konsisten sesuai aturan Husky & Conventional Commits.
---

# Commit Convention & Husky Enforcement (Wajib)

> [!CAUTION]
> **PERINGATAN KERAS: JANGAN PERNAH MEM-BYPASS HOOK GIT DENGAN ALASAN APA PUN!**
> Dilarang keras menggunakan opsi `--no-verify`, `-n`, atau mematikan `HUSKY=0` saat melakukan commit.
> Jika hook Husky (ESLint, Prettier, Pint, PHPStan, Commitlint) gagal, **perbaiki kesalahan kode/pesan commit tersebut sampai lolos secara natural**.
> Mengabaikan atau mem-bypass hook dianggap sebagai pelanggaran berat terhadap standar integritas kode proyek.

Gunakan workflow ini **HANYA saat user secara eksplisit meminta atau mengonfirmasi untuk melakukan commit**.
**DILARANG KERAS berinisiatif melakukan commit otomatis** setelah membuat atau mengedit file. Laporkan perubahan terlebih dahulu dan tunggu konfirmasi user.

---

## 1. Verifikasi Pra-Commit (Husky Simulation & Health Check)

Sebelum menjalankan `git commit`, Agent **WAJIB** memvalidasi dan memastikan seluruh checks yang ada di `.husky/pre-commit` lolos:

1. **Format PHP (Laravel Pint):**
   - Jalankan pemformatan: `composer format:php`
   - Pastikan tidak ada pelanggaran: `composer format:php:check`
2. **Linter JS/TS/Vue (ESLint):**
   - Jalankan linter: `npm run lint` (atau `npm run lint:fix` jika perlu perbaikan otomatis)
3. **Format JS/TS/Vue/CSS (Prettier):**
   - Periksa format: `npm run format:check` (atau `npm run format` jika perlu perbaikan otomatis)
4. **Analisis Statis PHP (PHPStan):**
   - Jalankan analisis: `composer analyse`
   - Jika ada baseline yang perlu diperbarui karena perubahan arsitektural yang valid: `./vendor/bin/phpstan analyse --generate-baseline`
5. **Integritas Error Definition (bila ada perubahan backend / FormRequest / ErrorCode):**
   - Jalankan linter error: `php artisan error-definition:lint` (wajib lolos zero error `[VM-*]`)
   - Sinkronkan katalog error: `php artisan error-definition:generate` (pastikan `error-catalog.json` dan `error-codes.ts` ter-update)
6. **Kebersihan Kode & Diff:**
   - Pastikan tidak ada `console.log`, `dd()`, `dump()`, atau temporary debug code yang tertinggal.
   - Periksa spasi dan format diff: `git diff --check`
7. **Pengujian Frontend & Pencegahan Flaky Test:**
   - Jalankan test frontend yang relevan atau seluruh suite: `npm test` atau `npm run test:ci` (memastikan zero failure).
   - Pastikan tidak ada fixed `setTimeout(ms)` untuk menunggu operasi asinkron (wajib memakai `vi.waitFor()` atau `flushPromises()`).

---

## 2. Pengelompokan & Staging

1. Periksa status perubahan:
   - `git status --short`
   - `git diff --name-only`
   - `git diff`
2. Kelompokkan perubahan berdasarkan domain/fitur/file yang saling terkait. **Dilarang mencampur perubahan yang tidak saling berhubungan.**
3. Stage hanya file yang relevan untuk commit tersebut (`git add <file1> <file2>`).

---

## 3. Format Commit Message (Commitlint)

Pesan commit harus mematuhi aturan `.husky/commit-msg` (Commitlint Conventional Commits):

- **Struktur:**
  ```text
  <type>(<scope>): <subject>

  - <bullet point penjelasan perubahan 1>
  - <bullet point penjelasan perubahan 2>
  ```
- **Type yang diizinkan:** `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf`, `ci`, `build`.
- **Scope:** Nama modul/domain yang relevan (contoh: `dtsen`, `auth`, `roles`, `wilayah`, `ui`, `workflow`).
- **Subject:**
  - Ditulis dalam Bahasa Indonesia (kecuali type & scope).
  - Huruf kecil semua (`lowercase`).
  - Maksimal 100 karakter.
  - **TIDAK diakhiri tanda titik (`.`)**.
- **Body:**
  - Sisakan tepat **satu baris kosong** antara subject dan body.
  - Gunakan bullet points (`- `) yang menjelaskan apa yang diubah dan alasannya.
  - Maksimal 120 karakter per baris.
- **Aturan Atribusi AI:**
  - **DILARANG** menambahkan trailer `Co-Authored-By: Claude ...`, `Co-Authored-By: Gemini ...`, atau atribusi bot/AI lainnya di commit message.

---

## 4. Eksekusi & Penanganan Error

1. Eksekusi `git commit -m "..."`.
2. Jika hook Husky gagal:
   - Baca log kegagalan secara detail (apakah ESLint, Prettier, Pint, PHPStan, atau Commitlint).
   - Perbaiki akar masalahnya langsung pada kode atau pesan commit.
   - **JANGAN PERNAH mencoba mem-bypass dengan `git commit --no-verify`**.
   - Ulangi langkah verifikasi dan commit.
3. Setelah semua commit selesai, pastikan `git status --short` bersih dan laporkan:
   - Hash commit (singkat 7 karakter).
   - Subject commit.
   - Ringkasan poin perubahan.
