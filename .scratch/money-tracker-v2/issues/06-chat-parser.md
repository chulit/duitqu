# 06: Chat-to-transaction parser

**What to build:** Ketik "makan siang 35 ribu pakai GoPay" di pil chat → dikenali
sebagai kandidat pengeluaran → simpan. Gantikan parser heuristik sederhana di
ChatSheet dengan pipeline `TransactionParser` yang sesungguhnya.

**Blocked by:** 01 (Fondasi kandidat), 05 (Inbox review).

**Status:** done (2026-10-16)

- [ ] `TransactionParser` interface: normalisasi → identifikasi sumber → ekstraksi field (tipe, nominal, merchant, akun, kategori, tanggal)
- [ ] Intent: income, expense, transfer ("transfer 500 ribu dari BCA ke GoPay" → transfer konsisten dua sisi via TransferService)
- [ ] Nominal format Indonesia: "35 ribu", "7 juta", "Rp28.000"
- [ ] Hasil ambigu → kandidat `needs_review` masuk inbox (bukan tebakan)
- [ ] AI/parser tidak pernah write langsung ke database
- [ ] Unit test: parsing nominal, klasifikasi tipe, merchant & category resolution

## Keputusan AI (2026-10-16)

**Parser deterministik dulu, AI jadi enhancement opsional nanti.**
Alasan: pola chat soal uang repetitif (80-90% tercover regex/rules);
yang ambigu ditangani via confidence → inbox review (arsitektur v2).
AI/LLM untuk 95%+ tapi butuh internet, ada biaya/latensi, dan data
keuangan dikirim ke server — nabrak offline-first + privacy-first.

Bila AI ditambahkan nanti: **hybrid opt-in** — deterministik default,
cloud LLM (Z.AI free tier, sudah dipakai untuk Hermes) hanya sebagai
fallback untuk kasus ambigu. On-device belum layak (model 1-2GB,
kualitas ID pas-pasan di model kecil, nguras baterai).
