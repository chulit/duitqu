# 06: Transfer antar akun + biaya admin

**What to build:** Transfer sebagai tipe transaksi tersendiri (bukan
pengeluaran): pilih akun sumber → akun tujuan + nominal. Field biaya admin
opsional — bila diisi, otomatis tercatat sebagai pengeluaran kategori
"Biaya Admin" dari akun sumber. Transfer dikecualikan dari ringkasan belanja.

**Blocked by:** 02 (butuh akun).

**Status:** ready-for-agent

- [ ] Transfer memperbarui saldo kedua akun dengan benar
- [ ] Biaya admin (bila diisi) tercatat sebagai pengeluaran "Biaya Admin"
- [ ] Transfer TIDAK muncul di total pengeluaran ringkasan
- [ ] Unit test: saldo, fee, eksklusi dari agregat
