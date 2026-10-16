# 07: Chat koreksi & hapus transaksi

**What to build:** "Kopi tadi ternyata 28 ribu, bukan 25 ribu" mengubah transaksi
yang benar (bukan membuat baru). "Hapus catatan makan siang yang tadi" menghapus
dengan konfirmasi dulu.

**Blocked by:** 06 (Chat parser).

**Status:** done (2026-10-16)

- [ ] Resolusi konteks: "yang tadi" → transaksi sebelumnya yang relevan
- [ ] Koreksi mengubah transaksi yang ada; saldo/laporan ikut konsisten
- [ ] Penghapusan via chat wajib konfirmasi eksplisit
- [ ] Undo tersedia untuk transaksi hasil pencatatan otomatis
- [ ] Unit + widget test: koreksi tidak membuat duplikat; hapus aman
