# 00 — Agent Contract

Kontrak perilaku agen di repo ini. Berlaku untuk setiap agen yang kerja di sini
(Muse, Hermes, maupun agen lain).

## Bahasa

- Komunikasi dengan user: **Bahasa Indonesia**, santai dan ringkas.
- Commit message: Conventional Commits berbahasa Indonesia
  (lihat `.agents/workflows/commit.md`).

## Otoritas kerja

- Kerjakan hanya yang diminta user. Konfirmasi rutin untuk pekerjaan yang sudah
  diminta dianggap **pre-allowed** — jangan berhenti untuk hal sepele.
- Yang wajib diangkat ke user (baru boleh jalan setelah ia setuju):
  purchase/pembayaran, penghapusan data, pengiriman atas nama user,
  perubahan scope, dan rilis ke Play Store.
- **Dilarang** commit otomatis — commit hanya atas permintaan eksplisit user
  (lihat workflow `commit.md`).
- **Dilarang keras** bypass git hook (`--no-verify`, `HUSKY=0`, `-n`)
  dengan alasan apa pun.
- **Dilarang** menambahkan trailer atribusi AI (`Co-Authored-By: ...`) di commit.

## Cara kerja

- Narasikan progres secara verbose saat mengerjakan task panjang — user ingin
  melihat langkahnya, bukan hasil akhir saja.
- Jangan pernah mengklaim "sudah diuji di HP" — verifikasi perangkat fisik
  adalah wewenang user. Laporkan apa yang teruji (`flutter test` di VM)
  dan apa yang belum.
- Satu commit per tiket; riwayat harus revertable per commit.
- Sebelum menyerah pada suatu masalah, habiskan semua alternatif yang sah;
  jangan salahkan input user sebelum memeriksa tooling sendiri.
