# DuitQu — Money Tracker

Aplikasi Android pencatat pemasukan & pengeluaran. 100% offline, data tersimpan
lokal di HP — tanpa akun, tanpa server, tanpa analytics.

## Fitur

- **Catat kilat** — catat transaksi maksimal 2 tap dari layar utama, dengan
  default cerdas (akun & kategori terakhir dipakai)
- **Akun** — bank, cash, e-wallet, lainnya; saldo awal manual per akun
- **Kategori** — 12 kategori bawaan + kategori kustom
- **Transfer antar akun** — tipe tersendiri (tidak dihitung sebagai pengeluaran);
  biaya admin opsional otomatis tercatat sebagai pengeluaran "Biaya Admin"
- **Rincian item** — nama barang, harga, qty per transaksi; total dihitung otomatis
- **Ringkasan bulanan** — total masuk, keluar, selisih + navigasi bulan
- **Filter & cari** — berdasarkan akun, kategori, dan teks (catatan/merchant/nama barang)
- **Backup CSV** — ekspor & impor manual satu file *(dalam pengerjaan)*
- **Tema gelap** mengikuti tema sistem

> Status: v1 dalam pengembangan aktif. Lokalisasi Inggris menyusul.

## Arsitektur

Clean architecture yang disederhanakan (mengikuti pola Status Saver):

```
lib/src/
├── presentation/   # UI tipis: layar, theme, format (tanpa logika bisnis)
├── domain/         # entity, interface repository, service murni (pure Dart)
└── data/           # drift/SQLite: implementasi repository, BackupService
```

- `TransactionRepository` adalah seam utama — seluruh akses data lewat interface ini.
- Aturan data: tidak ada hapus otomatis, tidak ada TTL; impor CSV divalidasi dulu
  sebelum menulis; nominal & tanggal tidak pernah diubah programatik.

## Pengembangan

```bash
flutter pub get
flutter analyze   # harus bersih
flutter test      # harus hijau
```

Build APK hanya lewat CI (GitHub Actions); VM pengembangan tidak menjalankan
build Gradle karena keterbatasan RAM.

## Privasi

Seluruh data keuangan tersimpan di SQLite lokal perangkat. Tidak ada data yang
dikirim ke mana pun.

## Lisensi

Menunggu keputusan pemilik.
