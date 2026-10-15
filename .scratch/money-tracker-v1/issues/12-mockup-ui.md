# Tiket 12 — UI sesuai mockup (visual dulu, tanpa fitur v4)

Sumber: `workspace/user/files/17920653561635592854004913408481_2_rs68.png`

## Scope
- Rebuild visual mengikuti mockup: Home, Insight, Inbox, Tujuan, Profil & Lainnya,
  floating navbar + chat input (4 state).
- Data real dipakai di mana sudah ada (saldo, transaksi, kategori, akun).
- Budget & Tujuan: simpan lokal sederhana (SharedPreferences), mulai dari kosong —
  tanpa data palsu.
- Inbox Auto-Catat: UI + empty state (sumber data notifikasi = v4, plan user).
- Chat AI/voice: UI state saja; tombol Simpan prefill sheet tambah transaksi.

## Tidak termasuk
- Backend Auto-Catat (baca notifikasi), AI/NLP beneran, STT, sinkronisasi cloud.

## AC
- 5 layar sesuai mockup, floating nav dengan chat pill di tengah.
- Ilustrasi hero digambar ulang sederhana (CustomPainter), bukan aset mockup.
- `flutter analyze` bersih, `flutter test` hijau.
