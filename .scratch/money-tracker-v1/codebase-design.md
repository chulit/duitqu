# Codebase Design: money-tracker v1

Bahasa desain mengikuti skill `codebase-design`: **Module** (sesuatu ber-interface
dan ber-implementasi), **Interface** (semua yang harus diketahui caller:
signature + invariant + error mode + karakteristik), **Seam** (lokasi interface
berada — tempat perilaku bisa diubah tanpa mengedit di situ), **Adapter**
(pemenuh interface di suatu seam), **Depth** (banyak perilaku di balik interface
kecil).

Arsitektur: presentation (tipis) → domain (pure Dart) → data (drift/SQLite).
Seam eksternal hanya di interface repository/service; UI dan test menyeberangi
seam yang sama.

## Modul 1: TransactionRepository — SEAM UTAMA

Interface (kecil, dalam):

- `save(Transaction t) -> id` — insert atau update; bila `t.items` tidak kosong,
  `amount` dihitung dari item (invariant: amount == sum(price*qty) bila ada item).
- `delete(id)` — hapus transaksi beserta item-nya (satu unit).
- `list(TransactionQuery q) -> List<Transaction>` — filter siap pakai:
  rentang tanggal, akun, kategori, merchant, teks pencarian, tipe.
  Kompleksitas query (join item, ordering, pagination) disembunyikan di dalam.
- `watch(TransactionQuery q) -> Stream<List<Transaction>>` — untuk UI reaktif.

Depth: caller belajar 4 method, dapat CRUD + query + reaktivitas + konsistensi
amount-vs-item. Deletion test: hapus modul ini dan logika konsistensi + query
menyebar ke semua caller — ia earning its keep.

Adapter: `DriftTransactionRepository` (produksi) dan in-memory fake (test).
Dua adapter = seam yang nyata, bukan hipotetis. Fake dipakai `flutter test`
di VM Linux tanpa emulator.

## Modul 2: AccountRepository

Interface:

- `save(Account a) -> id`, `delete(id)` (dilarang bila masih ada transaksi —
  error mode eksplisit, bukan silent), `list() -> List<Account>`.
- `balance(accountId, {DateTime? upTo}) -> Money` — saldo = initialBalance +
  pemasukan − pengeluaran ± transfer. Seluruh aritmetika di dalam modul.

Depth: satu method `balance` menyembunyikan tiga tipe transaksi dan time-travel.

## Modul 3: CategoryRepository

Interface: `defaults() -> List<Category>` (bawaan, read-only),
`save(Category c) -> id`, `delete(id)` (dilarang bila dipakai transaksi),
`list() -> List<Category>`.

Sengaja dangkal: tidak ada perilaku yang disembunyikan, dan itu benar —
modul ini memang hanya penyimpanan.

## Modul 4: SummaryService — pure, paling dalam

Interface (satu method):

- `summarize(List<Transaction> txs, Period p) -> Summary` — di mana `Summary`
  = {income, expense, net, byCategory, byMerchant, byAccount, runningBalance}.

Tidak ada dependensi framework, tidak ada I/O: input list, output ringkasan.
Depth maksimal — seluruh agregasi, pengelompokan, dan running balance di balik
satu signature. Test: tabel kasus murni, tanpa fake apa pun.

## Modul 5: BackupService

Interface:

- `exportCsv() -> File` — semua transaksi + item + akun + kategori, satu file.
- `importCsv(File f) -> ImportReport` — validasi dulu, tulis kemudian;
  `ImportReport` = {imported, skipped: [baris + alasan]}. Tidak pernah
  setengah-tulis: gagal validasi fatal → tidak ada yang ditulis.

Invariant keamanan: impor tidak boleh merusak data yang sudah ada
(lihat `14-data-safety.md`).

## Keputusan seam

- Seam tertinggi/pertama untuk testing: `TransactionRepository`. Semua test
  repository dan sebagian besar widget test menyeberang di sini.
- `SummaryService` tidak butuh seam baru: ia pure function.
- Tidak ada seam untuk database engine selain dua adapter di atas —
  satu adapter (drift) + satu fake (test) sudah cukup; abstraksi "bisa ganti
  ke database lain" adalah seam hipotetis dan tidak dibuat.
- Internal seam (private, untuk test modul sendiri) diizinkan; bukan bagian
  dari interface publik modul.

## Yang ditolak

- Repository generik `BaseRepository<T>`: mengorbankan depth demi DRY semu —
  tiap repository punya invariant sendiri (konsistensi amount, larangan hapus).
- Query builder diekspos ke caller: kompleksitas query adalah implementation,
  bukan interface.
