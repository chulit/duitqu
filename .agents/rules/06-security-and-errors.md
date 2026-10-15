# 06 — Security and Errors

## Keamanan

- Aplikasi **100% lokal/offline**: tanpa akun, tanpa backend, tanpa analytics,
  tanpa crash reporter pihak ketiga. Ini keputusan sadar — jangan "memperbaiki"
  dengan menambahkan dependensi network tanpa persetujuan user.
- **Dilarang** menyimpan secret, API key, atau token di repo maupun di kode.
- Data transaksi tidak boleh keluar dari perangkat dalam bentuk apa pun kecuali
  atas aksi eksplisit user (ekspor CSV).

## Error handling

- Dilarang silent failure. Setiap kegagalan yang berdampak ke user harus
  terlihat dan bisa dipahami.
- Pesan error untuk user: Bahasa Indonesia, ramah, dan actionable
  ("Gagal menyimpan. Coba lagi." — bukan stack trace).
- Detail teknis (exception, stack trace) dicatat ke log lokal untuk debugging,
  tidak ditampilkan ke user.
- Validasi input di domain, bukan cuma di UI: nominal harus > 0, tanggal valid,
  kategori harus ada.
- Aksi destruktif (hapus transaksi/kategori) wajib konfirmasi eksplisit di UI.
  Tidak ada hapus diam-diam.
