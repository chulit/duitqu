import '../entities/transaction_candidate.dart';

/// Seam untuk kandidat transaksi (tiket 01, spec v2).
///
/// Kandidat adalah hasil parsing yang belum tentu menjadi transaksi.
/// Penyimpanan kandidat terpisah dari transaksi finansial.
abstract class CandidateRepository {
  /// Simpan kandidat. Idempoten: bila kandidat dengan fingerprint sama
  /// sudah ada, kembalikan id yang sudah ada tanpa membuat record baru
  /// (tiket 03).
  Future<int> save(TransactionCandidate candidate);

  /// Perbarui kandidat yang ada (mis. transisi status).
  Future<void> update(TransactionCandidate candidate);

  /// Ambil kandidat berdasarkan id. Null bila tidak ada.
  Future<TransactionCandidate?> getById(int id);

  /// Daftar kandidat berdasarkan status, terbaru dulu.
  Future<List<TransactionCandidate>> listByStatus(CandidateStatus status);

  /// Cari kandidat dengan fingerprint sama (untuk duplicate detection).
  Future<TransactionCandidate?> findByFingerprint(String fingerprint);

  /// Hapus kandidat (mis. data review yang sudah tidak diperlukan).
  Future<void> delete(int id);
}
