# 02: Pelacakan sumber di transaksi

**What to build:** Setiap transaksi mencatat asalnya (manual, chat, notifikasi, dsb)
lewat kolom baru, sehingga pengguna bisa melihat "angka ini dari mana" dan
memperbaiki hasil pencatatan otomatis.

**Blocked by:** None (can start immediately).

**Status:** done (2026-10-16)

- [ ] Kolom `origin`, `status`, `source_candidate_id`, `transfer_group_id` di tabel transactions (nama logis; selaraskan dengan drift)
- [ ] Migrasi preservasi data
- [ ] Transaksi manual tercatat dengan origin=manual
- [ ] Unit test: origin tersimpan dan terbaca kembali
