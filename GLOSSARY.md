# Money Tracker

Bahasa domain aplikasi pencatat keuangan pribadi. Istilah di sini dipakai di
spec, tiket, nama test, dan UI. Konsisten — jangan pakai sinonim di daftar
_Avoid_.

## Transaksi & uang

**Transaksi**:
Satu kejadian uang yang dicatat: pemasukan, pengeluaran, atau transfer.
_Avoid_: mutasi, entry

**Pemasukan**:
Transaksi uang masuk ke sebuah akun.
_Avoid_: income (di UI), kredit

**Pengeluaran**:
Transaksi uang keluar dari sebuah akun.
_Avoid_: expense (di UI), debit

**Transfer**:
Perpindahan uang antar akun milik sendiri. Bukan pengeluaran dan tidak
mengurangi total belanja pada ringkasan.
_Avoid_: pemindahan (tidak konsisten)

**Akun**:
Wadah uang: bank, cash, e-wallet, atau lainnya. Setiap transaksi terikat ke
satu akun (transfer ke dua akun).
_Avoid_: dompet (terlalu sempit), rekening (terlalu sempit)

**Saldo**:
Posisi uang di sebuah akun = saldo awal + pemasukan − pengeluaran ± transfer.
_Avoid_: balance (di UI)

## Rincian

**Kategori**:
Pengelompokan transaksi (mis. Makan, Transport). Ada bawaan dan kustom.
_Avoid_: tag, label

**Item**:
Rincian satu produk di dalam sebuah transaksi belanja (nama + harga + qty).
Satu transaksi bisa punya banyak item, seperti struk.
_Avoid_: produk (item adalah baris rincian, bukan katalog produk)

**Merchant**:
Tempat transaksi terjadi, sebagai field sendiri (mis. "Indomaret A", "PLN").
_Avoid_: toko (terlalu sempit), store

## Waktu & ringkasan

**Periode**:
Rentang waktu ringkasan: harian, mingguan, atau bulanan.
_Avoid_: jangka waktu

**Ringkasan**:
Agregat transaksi per periode: total pemasukan vs pengeluaran, sisa,
pengelompokan per kategori/merchant/akun, dan saldo berjalan.
_Avoid_: laporan (terlalu formal), report
