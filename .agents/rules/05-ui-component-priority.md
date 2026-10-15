# 05 — UI Component Priority

## Urutan prioritas saat butuh komponen UI

1. Komponen bawaan framework (Material 3) — jangan reinvent.
2. Widget shared yang sudah ada di proyek (`lib/widgets/`).
3. Widget baru — hanya bila 1 dan 2 tidak memenuhi, dan **wajib reusable**
   (bukan one-off untuk satu layar). Taruh di `lib/widgets/`, bukan
   di dalam file layar.

## Aturan

- Satu bahasa desain di seluruh aplikasi. Inkonsistensi visual adalah bug.
- String UI: Bahasa Indonesia sebagai utama, Bahasa Inggris wajib ikut
  (pola lokalisasi penuh EN/ID seperti Status Saver). Tidak ada string
  hardcode di widget — lewat sistem lokalisasi.
- Format angka: Rupiah via `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp')`.
- **Kejujuran data**: nilai yang belum terkumpul/belum ada dirender sebagai
  `'—'`, tidak pernah difabrikasi. Empty state harus informatif, bukan
  halaman kosong yang membingungkan.
- Target sentuh minimum 48dp; kontras teks memenuhi standar baca.
- Tambah transaksi harus bisa selesai maksimal 2 tap dari layar utama —
  kecepatan catat adalah nyawa aplikasi ini.
