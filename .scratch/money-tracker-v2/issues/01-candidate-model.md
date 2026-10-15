# 01: Fondasi kandidat transaksi

**What to build:** Model `TransactionCandidate` (entity pure Dart) + `CandidateRepository`
(interface + implementasi drift) + tabel `transaction_candidates` + migrasi database.
Kandidat punya status pemrosesan: received, parsing, needs_review, ready_to_save,
saved, duplicate, ignored, failed.

**Blocked by:** None (can start immediately).

**Status:** done (2026-10-16)

- [ ] Entity `TransactionCandidate` dengan semua field §8.2 spec (source_type, source_app, source_reference, fingerprint, parsed_payload, confidence, processing_status, review_reason, transaction_id, received_at, processed_at)
- [ ] `CandidateRepository` interface: save, updateStatus, listByStatus, findByFingerprint
- [ ] Tabel drift + migrasi (preservasi data, aturan 14-data-safety)
- [ ] Unit test: simpan/query kandidat per status
