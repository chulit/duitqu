# 14 — Data Safety

Data keuangan user adalah data sakral. Aturan ini di atas kenyamanan implementasi.

## Aturan

- **Tidak ada penghapusan atau penimpaan data** kecuali atas aksi eksplisit
  user di UI (dengan konfirmasi, lihat `06-security-and-errors.md`).
- **Tidak ada auto-delete, tidak ada TTL** pada data user. Data 5 tahun lalu
  sama berharganya dengan data hari ini.
- Migrasi skema (drift): wajib preservasi data. Setiap migrasi yang mengubah
  atau memindahkan kolom harus punya test migrasi (db lama → db baru,
  data utuh).
- Ekspor CSV adalah mekanisme backup v1:
  - Ekspor harus lengkap (semua kolom, semua baris) dan valid.
  - Impor harus **divalidasi dulu sebelum menulis apa pun**; baris rusak
    dilaporkan per-baris dan dilewati, tidak menggagalkan seluruh impor
    secara diam-diam dan tidak merusak data yang sudah ada.
- Dilarang mengubah nominal/tanggal transaksi secara programatik
  (pembulatan, normalisasi zona waktu, dsb.) tanpa persetujuan user —
  angka yang dicatat user adalah kebenaran.
- Sebelum operasi massal apa pun (impor, migrasi besar), pastikan ada jalan
  kembali (backup/rollback).
