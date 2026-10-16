import '../../data/notification_bridge.dart';
import '../entities/transaction_candidate.dart';
import '../repositories/candidate_repository.dart';
import 'auto_record_policy.dart';
import 'duplicate_detector.dart';

/// Pipeline: notifikasi Android → kandidat → kebijakan (tiket 09, spec v2).
///
/// Alur: terima notifikasi → parse dasar → cek duplikat → evaluasi
/// kebijakan → simpan kandidat (auto-save langsung jadi transaksi
/// ditangani tahap berikutnya; di sini kandidat disimpan dengan
/// status sesuai kebijakan).
class NotificationPipeline {
  final CandidateRepository _candidateRepo;
  final AutoRecordPolicy _policy;
  final DuplicateDetector _detector;

  NotificationPipeline(
    this._candidateRepo, [
    AutoRecordPolicy? policy,
    DuplicateDetector? detector,
  ])  : _policy = policy ?? AutoRecordPolicy(),
        _detector = detector ?? DuplicateDetector();

  /// Proses satu notifikasi menjadi kandidat.
  /// Mengembalikan null bila notifikasi diabaikan (bukan transaksi).
  Future<TransactionCandidate?> process(
    RawNotification notif,
    AutoRecordSettings settings,
  ) async {
    // Parse dasar: gabung judul + isi.
    final text = '${notif.title} ${notif.text}'.trim();
    if (text.isEmpty) return null;

    // Ekstrak nominal sederhana (parser notifikasi detail di tiket 10).
    final amount = _extractAmount(text);
    if (amount == null || amount <= 0) return null;

    var candidate = TransactionCandidate(
      sourceType: CandidateSourceType.androidNotification,
      sourceApp: notif.packageName,
      sourceReference: '${notif.packageName}:${notif.id}:${notif.postedAt.millisecondsSinceEpoch}',
      parsedPayload: {
        'transaction_type': _guessType(text),
        'amount': amount,
        'merchant': notif.title,
        'description': notif.text,
        'occurred_at': notif.postedAt.millisecondsSinceEpoch,
      },
      confidence: 0.7,
      status: CandidateStatus.parsing,
      receivedAt: DateTime.now(),
    );

    // Fingerprint + cek duplikat.
    final fp = _detector.fingerprint(candidate);
    candidate = candidate.copyWith(fingerprint: fp);
    final existing = await _candidateRepo.findByFingerprint(fp);
    final isDuplicate = existing != null;

    // Evaluasi kebijakan.
    final decision = _policy.evaluate(
      candidate,
      settings,
      isDuplicate: isDuplicate,
    );

    final status = switch (decision.decision) {
      PolicyDecision.autoSave => CandidateStatus.readyToSave,
      PolicyDecision.needsReview => CandidateStatus.needsReview,
      PolicyDecision.ignore =>
        isDuplicate ? CandidateStatus.duplicate : CandidateStatus.ignored,
    };

    candidate = candidate.copyWith(
      status: status,
      reviewReason: decision.reason,
      processedAt: DateTime.now(),
    );

    // Simpan idempoten (tiket 03).
    final id = await _candidateRepo.save(candidate);
    return (await _candidateRepo.getById(id))!;
  }

  int? _extractAmount(String text) {
    final m = RegExp(
      r'rp\s?([\d\.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    final numStr = m.group(1)!.replaceAll('.', '').replaceAll(',', '.');
    final value = double.tryParse(numStr);
    return value?.round();
  }

  String _guessType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('terima') ||
        lower.contains('masuk') ||
        lower.contains('diterima')) {
      return 'income';
    }
    return 'expense';
  }
}
