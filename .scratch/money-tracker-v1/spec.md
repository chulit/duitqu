# Spec: DuitQu — Money Tracker v1 (Android, Flutter)

Status: ready-for-agent

## Problem Statement

Pengguna ingin mencatat pemasukan dan pengeluaran uang harian dari HP Android-nya,
tapi aplikasi pencatat keuangan yang ada umumnya berat, penuh iklan, atau mengunci
fitur inti di balik langganan. Ia butuh aplikasi yang ringan, cepat dibuka,
privat (data uang adalah data sensitif), dan gratis penuh tanpa paywall.

## Solution

Aplikasi Android native-feel berbasis Flutter, 100% lokal/offline tanpa akun,
tanpa backend, tanpa analytics — seluruh data transaksi tersimpan di perangkat
pengguna. Pengguna bisa mencatat pemasukan/pengeluaran dalam hitungan detik,
melihat riwayat, dan mendapat ringkasan sederhana (harian/mingguan/bulanan)
agar tahu uangnya lari ke mana.

## User Stories

1. As a pengguna, I want mencatat pengeluaran (nominal, kategori, tanggal, catatan opsional), so that setiap uang keluar tercatat tanpa ribet.
2. As a pengguna, I want mencatat pemasukan (nominal, sumber/kategori, tanggal, catatan opsional), so that uang masuk ikut terpantau.
3. As a pengguna, I want menambah transaksi dalam < 10 detik dari layar utama, so that saya tidak malas mencatat.
4. As a pengguna, I want melihat daftar riwayat transaksi terurut waktu, so that saya bisa menelusuri kembali pengeluaran saya.
5. As a pengguna, I want mengedit transaksi yang salah catat, so that data tetap akurat tanpa harus hapus-buat ulang.
6. As a pengguna, I want menghapus transaksi, so that catatan yang batal/duplikat bisa dibersihkan.
7. As a pengguna, I want kategori bawaan yang masuk akal (makan, transport, belanja, tagihan, gaji, dll), so that saya langsung pakai tanpa setup.
8. As a pengguna, I want membuat kategori sendiri, so that kategori sesuai gaya hidup saya.
9. As a pengguna, I want melihat ringkasan pengeluaran per hari/minggu/bulan, so that saya tahu pola belanja saya.
10. As a pengguna, I want melihat total pemasukan vs pengeluaran per periode, so that saya tahu sisa/nettonya.
11. As a pengguna, I want melihat saldo berjalan (running balance), so that saya tahu posisi keuangan saat ini.
12. As a pengguna, I want memfilter riwayat per kategori dan rentang tanggal, so that saya bisa audit pos tertentu.
13. As a pengguna, I want mencari transaksi berdasarkan catatan/nominal, so that saya cepat menemukan transaksi lama.
14. As a pengguna, I want format angka Rupiah (Rp) yang benar, so that nominal mudah dibaca.
15. As a pengguna, I want seluruh data tersimpan lokal di HP saya, so that data keuangan sensitif tidak keluar ke server mana pun.
16. As a pengguna, I want mengekspor data ke CSV, so that saya punya backup dan bisa olah di spreadsheet.
17. As a pengguna, I want mengimpor kembali data dari file backup, so that data tidak hilang saat ganti HP.
18. As a pengguna, I want tampilan Bahasa Indonesia, so that aplikasi terasa natural dipakai harian.
19. As a pengguna, I want mode gelap, so that nyaman dipakai malam hari.
20. As a pengguna, I want aplikasi ringan dan cepat dibuka, so that mencatat tidak jadi beban.
21. As a pengguna, I want memecah satu transaksi belanja menjadi item-item produk beserta harganya masing-masing (mis. Belanja Indomaret A: Produk 1 Rp8.888, Produk 2 Rp683.883), so that saya tahu rincian belanjaan, bukan cuma totalnya.
22. As a pengguna, I want total transaksi terhitung otomatis dari jumlah item, so that saya tidak perlu menjumlah manual.
23. As a pengguna, I want item bersifat opsional — kalau malas, cukup catat totalnya saja, so that mencatat tetap cepat saat buru-buru.
24. As a pengguna, I want mencatat jumlah (qty) per item, so that harga satuan dan total per produk tercatat benar.
25. As a pengguna, I want mendaftarkan akun-akun saya (bank, cash, e-wallet, dll), so that setiap transaksi tercatat dari/ke akun yang benar.
26. As a pengguna, I want melihat saldo per akun, so that saya tahu isi tiap akun tanpa buka m-banking satu-satu.
27. As a pengguna, I want mencatat transaksi ke akun tertentu, so that pemasukan/pengeluaran mengurangi/menambah saldo akun yang tepat.
28. As a pengguna, I want mencatat transfer antar akun (mis. tarik tunai BCA → cash), so that perpindahan uang antar akun tetap terlacak tanpa dianggap pengeluaran.
29. As a pengguna, I want mencatat nama toko/merchant per transaksi (field sendiri, mis. "Indomaret A"), so that saya bisa membandingkan pengeluaran antar toko.

## Implementation Decisions

- **Platform**: Flutter, Android-first. Struktur kode disiapkan agar iOS bisa menyusul tanpa rewrite (tidak ada dependensi Android-only di domain/data layer).
- **Arsitektur**: clean architecture yang disederhanakan untuk aplikasi utilitas satu fitur (mengikuti pola Status Saver). Modul dalam (detail di `codebase-design.md`):
  - `TransactionRepository` — CRUD + query/filter + stream reaktif; menjaga invariant amount == sum(item) (SEAM UTAMA untuk testing; adapter drift + in-memory fake)
  - `AccountRepository` — CRUD akun + `balance(accountId)` (saldo awal + pemasukan − pengeluaran ± transfer)
  - `CategoryRepository` — kategori bawaan (read-only) + kustom
  - `SummaryService` — pure function: agregasi periode, byCategory/byMerchant/byAccount, running balance
  - `BackupService` — ekspor/impor CSV; impor tervalidasi dulu, tulis kemudian, tidak pernah setengah-tulis
  - UI layer (presentation) tipis, logika di domain. Seam eksternal hanya di interface repository/service.
- **Persistensi**: SQLite lokal via `drift` (type-safe, migrasi skema terkendali). Tanpa Firebase/backend/analytics — penyimpangan sadar dari default skill demi janji privasi.
- **Mata uang**: IDR default dengan format `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp')`.
- **Lokalisaasi**: Bahasa Indonesia sebagai bahasa utama; Bahasa Inggris disertakan mengikuti pola Status Saver (EN/ID penuh).
- **Desain**: mengikuti prinsip ringan — cold start cepat, tambah-transaksi maksimal 2 tap dari home.
- **Distribusi v1**: sideload APK untuk pemakaian pribadi (mengikuti pola Status Saver); rilis Play Store di luar scope v1.

## Testing Decisions

- Yang diuji adalah perilaku eksternal, bukan detail implementasi.
- **Unit test wajib** (mengikuti keputusan pipeline mac-monitor): `TransactionRepository`, `AccountRepository`, `CategoryRepository`, `SummaryService`, `BackupService` — semuanya pure Dart / in-memory SQLite sehingga bisa jalan di VM Linux ini via `flutter test` tanpa perangkat.
- Widget test untuk alur kritis: tambah transaksi, daftar riwayat, ringkasan bulanan.
- Tidak ada test yang bergantung pada perangkat Android fisik; verifikasi di HP diserahkan ke pengguna (pola yang sama seperti mac-monitor di Mac).

## Out of Scope

- iOS (siap secara arsitektur, tapi build & uji iOS bukan v1)
- Sinkronisasi cloud / multi-device → **roadmap v1.x** (bukan ditunda tanpa rencana)
- Multi-currency → **v1.x**; v1 fokus IDR dulu (keputusan grill ronde 2)
- Integrasi bank, e-wallet, atau impor mutasi otomatis
- Anggaran (budget) & pengingat/notifikasi pengeluaran
- OCR struk / scan nota
- Grafik/diagram kompleks (cukup angka ringkasan di v1; visualisasi masuk v1.x)
- Rilis Play Store
- Ekspor CSV otomatis terjadwal — ditolak; digantikan rencana cloud sync

## Further Notes

- **Keputusan yang sudah final** (hasil diskusi + grill ronde 1, 2026-10-15): nama aplikasi **DuitQu — Money Tracker**; akun bank/cash/e-wallet dengan saldo per akun (saldo awal diisi manual, default Rp0); transfer antar akun sebagai tipe transaksi khusus (bukan pengeluaran) + field biaya admin opsional yang otomatis tercatat sebagai pengeluaran kategori "Biaya Admin"; line item produk opsional per transaksi (nama+harga+qty, total otomatis); merchant sebagai field sendiri (teks + saran otomatis); **multi-currency** (desain menyusul ronde 2); form catat kilat memakai default cerdas (akun & kategori terakhir dipakai, tanggal hari ini); Play Store ditunda (v1 sideload pribadi); workflow GitHub replika Status Saver; 100% lokal/offline dikonfirmasi.
- **Masih terbuka**: repo GitHub `chulit/duitqu` + applicationId `id.chulit.duitqu` (keputusan pengguna, grill ronde 2).
- Identitas: repo `~/workspace/money-tracker` (nama kerja; repo GitHub `chulit/duitqu`), applicationId `id.chulit.duitqu`.
- Kategori bawaan v1: Makan & Minum, Transport, Belanja, Tagihan, Pulsa & Internet, Kesehatan, Hiburan, Pendidikan, Gaji, Bonus, Biaya Admin, Lainnya (disetujui sementara; pengguna tambah bila kurang).
- Dokumen pendukung: `prd.md` (kebutuhan produk), `codebase-design.md` (desain modul dalam), `GLOSSARY.md` (root repo), `docs/adr/` (0001 local-first, 0002 transfer, 0003 line-item).
- Skema data awal (keputusan, bukan path file): Transaction(id, type[income|expense|transfer], amount, categoryId, accountId, toAccountId, merchant, date, note, createdAt), Category(id, name, icon, color, isDefault), Account(id, name, type[bank|cash|ewallet|other], initialBalance, icon, color, createdAt), TransactionItem(id, transactionId, name, price, qty) — relasi satu-ke-banyak; amount transaksi = sum(price*qty) bila ada item, else nilai manual.
- **Merchant sebagai field sendiri**: teks bebas dengan saran otomatis dari merchant yang pernah dipakai. Mendukung ringkasan per merchant ("bulan ini habis berapa di Indomaret vs Alfamart").
- **Line item per transaksi**: satu transaksi belanja bisa punya banyak item produk (nama + harga + qty). Total dihitung otomatis. Item opsional — transaksi tanpa item tetap valid (catat total langsung).
- **Akun (bank, cash, e-wallet)**: entity `Account(id, name, type[bank|cash|ewallet|other], initialBalance, icon, color)`. Setiap transaksi terikat ke satu akun; saldo akun = saldo awal + pemasukan − pengeluaran ± transfer. Transfer adalah tipe transaksi khusus (`type=transfer`, `accountId` sumber → `toAccountId` tujuan) — bukan pengeluaran, jadi tidak merusak ringkasan belanja.
