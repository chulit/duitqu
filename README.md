# DuitQu — Money Tracker

![Build](https://github.com/chulit/duitqu/actions/workflows/build-apk.yml/badge.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.47-blue)
![Platform](https://img.shields.io/badge/Platform-Android-green)
![Offline](https://img.shields.io/badge/Offline--first-100%25-orange)

Aplikasi Android pencatat pemasukan & pengeluaran yang **100% offline-first**.
Semua data tersimpan lokal di HP (SQLite via Drift) — tanpa akun, tanpa
server, tanpa analytics. Cukup install, langsung pakai.

> Bahasa Indonesia utama, dengan lokalisasi Inggris.

## ✨ Fitur

### 💬 Pencatatan Cerdas
| Fitur | Cara kerja |
|---|---|
| **Chat Assistant** | Ketik "makan siang 35 ribu pakai GoPay" → tercatat. Bisa koreksi ("yang tadi 40 ribu"), hapus (dengan konfirmasi), undo, bahkan tanya jawab ("pengeluaran makan bulan ini berapa?") |
| **Scan Struk** | Foto struk → OCR on-device → kandidat transaksi otomatis |
| **Auto-Catat Notifikasi** | Notifikasi GoPay/BCA/dll dibaca otomatis jadi kandidat *(opt-in, izin via Pengaturan Android)* |
| **Catat Kilat** | Form manual 2-tap dengan default cerdas (akun & kategori terakhir) |

### 🛡️ Kandidat & Inbox — tidak ada transaksi "siluman"
Setiap input otomatis (chat ambigu, notifikasi, struk) menjadi **kandidat** dulu:
1. 🔍 Cek duplikat via fingerprint
2. ⚖️ Dievaluasi policy: *auto-save* vs *perlu review* vs *abaikan*
3. 📥 Masuk Inbox untuk dikonfirmasi

**Kandidat tidak pernah memengaruhi saldo sebelum kamu setujui.**

### 💰 Keuangan Lengkap
- **Akun** — bank, cash, e-wallet; saldo awal manual per akun
- **Kategori** — 12 bawaan + kustom sesukamu
- **Transfer antar akun** — tipe tersendiri (bukan pengeluaran); biaya admin otomatis tercatat sebagai "Biaya Admin"
- **Tujuan (Goals)** — target menabung dengan progress bar
- **Insight** — ringkasan bulanan, donat kategori, tips hemat otomatis
- **Rincian item** — nama barang, harga, qty per transaksi

### 🔒 Backup & Privasi
- **Backup CSV** — ekspor/impor manual satu file
- **Backup terenkripsi ke Google Drive** — AES-256-GCM, hanya folder `drive.appdata` *(end-to-end encrypted)*
- **Foto struk dihapus** setelah OCR; tidak ada isi notifikasi di log
- **Tema** — Terang / Gelap / Ikuti sistem

## 🏗️ Arsitektur

Clean architecture yang disederhanakan:

```
lib/src/
├── presentation/   # UI: layar, widget, theme, l10n
├── domain/         # entity, interface repository, service murni (pure Dart)
└── data/           # drift/SQLite, platform channel, ML Kit, sync
assets/mascot/     # maskot WebP (hero, expressions, poses, stickers)
```

**Prinsip utama:**
- `TransactionRepository` adalah **satu-satunya write gate** — semua tulis
  data transaksi lewat interface ini, tanpa kecuali.
- Tidak ada hapus otomatis, tidak ada TTL data.
- Impor selalu divalidasi sebelum menulis; nominal & tanggal tidak pernah
  diubah secara programatik.

## 🛠️ Pengembangan

```bash
flutter pub get
flutter analyze   # harus bersih
flutter test      # harus hijau (164 test)
```

**Rilis otomatis:** setiap push ke `main` memicu semantic-release di GitHub
Actions → build APK → publish ke GitHub Releases. Tanda tangan APK memakai
keystore permanen yang sama di setiap rilis.

> ⚠️ VM pengembangan tidak menjalankan build Gradle (keterbatasan RAM).
> Kode native (Kotlin) diverifikasi lewat CI.

## 📱 Izin Android

| Izin | Untuk | Sifat |
|---|---|---|
| `CAMERA` | Scan struk | Runtime — diminta saat dipakai |
| Notification Listener | Auto-catat notifikasi | Khusus — via Pengaturan → Akses notifikasi, opt-in eksplisit |

## 📄 Lisensi

Menunggu keputusan pemilik.
