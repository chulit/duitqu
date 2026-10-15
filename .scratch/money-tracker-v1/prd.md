# PRD: DuitQu — Money Tracker (v1)

Status: draft — menunggu review pengguna
Terakhir diperbarui: 2026-10-15

## 1. Latar belakang & masalah

Pengguna (developer Indonesia, pengguna Android) ingin mencatat pemasukan dan
pengeluaran harian, tetapi aplikasi pencatat keuangan yang ada umumnya:
berat dan lambat dibuka, penuh iklan, mengunci fitur inti di balik langganan,
dan menyimpan data keuangan sensitif di server pihak ketiga.

Ia butuh aplikasi yang: ringan dan cepat dibuka, gratis penuh tanpa paywall,
privat (data tidak keluar dari HP), dan cukup rinci untuk kebutuhan nyata —
misalnya belanja di Indomaret yang terdiri dari banyak produk dengan harga
satuan masing-masing, tersebar di beberapa akun (bank, cash, e-wallet).

## 2. Tujuan produk

Aplikasi Android pencatat keuangan pribadi yang bisa mencatat transaksi dalam
hitungan detik, memberi jawaban "uangku ke mana" dalam sekali lihat, dan
menjamin data 100% milik pengguna.

## 3. Pengguna

Satu pengguna: pemilik HP. Tidak ada multi-user, tidak ada peran, tidak ada
berbagi data di v1.

## 4. Fitur v1 (prioritas)

### P0 — wajib ada
1. **Akun**: daftar akun (bank, cash, e-wallet, lain-lain) dengan saldo awal;
   saldo per akun terhitung otomatis.
2. **Catat transaksi kilat**: pemasukan/pengeluaran dengan nominal, kategori,
   akun, tanggal, catatan opsional, dan merchant — maksimal 2 tap dari layar utama.
3. **Line item (struk)**: satu transaksi belanja bisa dipecah menjadi item
   produk (nama + harga + qty); total terhitung otomatis; item opsional.
4. **Riwayat**: daftar transaksi urut waktu; edit dan hapus (hapus dengan konfirmasi).
5. **Kategori**: bawaan yang masuk akal + kategori kustom.
6. **Transfer antar akun**: tipe transaksi khusus, bukan pengeluaran.
7. **Merchant**: field sendiri per transaksi (teks + saran otomatis);
   mendukung ringkasan per merchant.

### P1 — penting, tetap v1
8. **Ringkasan**: total pemasukan vs pengeluaran per hari/minggu/bulan + sisa;
   saldo berjalan; filter kategori/rentang tanggal/merchant; pencarian.
9. **Backup**: ekspor/impor CSV (impor tervalidasi per baris).

### P2 — fondasi non-fitur
10. 100% lokal/offline: tanpa akun, tanpa backend, tanpa analytics.
11. Bahasa Indonesia utama + Bahasa Inggris penuh.
12. Mode gelap.
13. Format Rupiah yang benar; angka tabular agar mudah di-scan.
14. Distribusi v1: sideload APK pemakaian pribadi (pola Status Saver);
    pipeline rilis semantic-release + split-per-abi seperti Status Saver.

## 5. Non-fitur (sengaja ditunda → v1.x)

Budget/anggaran & pengingat, grafik/diagram kompleks, scan struk (OCR),
integrasi bank/e-wallet (impor mutasi otomatis), build iOS, rilis Play Store.
**Roadmap v1.x** (direncanakan, bukan sekadar ditunda): sinkronisasi cloud
(lihat ADR 0001 — harus menjaga janji privasi, desain menyusul) dan
multi-currency (kurs via API gratis seperti exchangerate.host/frankfurter —
butuh internet, sehingga desainnya menunggu keputusan arsitektur sync).

## 6. Keputusan produk (sudah diputuskan)

- Merchant = field sendiri (bukan cuma catatan) — keputusan pengguna 2026-10-15.
- Transfer antar akun = tipe transaksi khusus — bukan pengeluaran.
- Line item per produk = ya, opsional per transaksi.
- Play Store = nanti; v1 sideload pribadi.
- Workflow GitHub = replika Status Saver (semantic-release, split-per-abi,
  keystore permanen, hard-fail bila signer tidak cocok).

## 7. Terbuka (butuh keputusan pengguna)

1. Saldo awal akun: diisi manual saat setup — DIPUTUSKAN 2026-10-15 (grill ronde 1).
   Sinkronisasi otomatis dengan bank tidak mungkin (tidak ada API resmi bank
   Indonesia; scraping rapuh + melanggar TOS) — tetap manual.
2. Keluhan utama terhadap aplikasi keuangan yang pernah dipakai
   (belum terjawab — akan mempertajam diferensiasi bila dijawab).

## 8. Metrik sukses (aplikasi pribadi)

- Dipakai mencatat setiap hari selama 30 hari berturut-turut.
- Waktu catat satu transaksi < 10 detik (diukur manual).
- Nol laporan kehilangan/kerusakan data.

## 9. Risiko

- Scope creep (fitur "bagus" seperti budget/OCR) menggerus kecepatan v1 —
  mitigasi: daftar Out of Scope dikunci di spec.
- Nama aplikasi belum ada menghambat scaffold & applicationId —
  mitigasi: pakai nama kerja sementara, rename sebelum rilis pertama.
