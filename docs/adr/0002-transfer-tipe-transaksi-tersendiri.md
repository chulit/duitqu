# Transfer adalah tipe transaksi tersendiri, bukan pengeluaran

Perpindahan uang antar akun (mis. tarik tunai BCA → cash) direpresentasikan
sebagai `type=transfer` dengan akun sumber dan akun tujuan, bukan sebagai
pasangan pengeluaran+pemasukan.

**Considered Options**: mencatat sebagai dua transaksi (pengeluaran dari akun A
+ pemasukan ke akun B).

**Alasan**: opsi dua-transaksi mengotori ringkasan belanja — uang yang hanya
berpindah akun akan terlihat sebagai "pengeluaran" dan merusak jawaban
"uangku ke mana". Tipe khusus membuat `SummaryService` bisa mengecualikan
transfer dari agregat belanja sambil tetap menjaga saldo kedua akun benar.
