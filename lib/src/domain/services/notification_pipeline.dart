import '../../data/notification_bridge.dart';
import '../entities/transaction_candidate.dart';
import '../repositories/candidate_repository.dart';
import 'auto_record_policy.dart';
import 'duplicate_detector.dart';
import 'notification_parsers.dart';

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
  final NotificationParserRegistry _parsers;

  /// Mapping package → nama akun default (dari setup tiket 09).
  final Map<String, String> sourceAccountMap;

  NotificationPipeline(
    this._candidateRepo, [
    AutoRecordPolicy? policy,
    DuplicateDetector? detector,
    NotificationParserRegistry? parsers,
    Map<String, String>? sourceAccountMap,
  ])  : _policy = policy ?? AutoRecordPolicy(),
        _detector = detector ?? DuplicateDetector(),
        _parsers = parsers ?? NotificationParserRegistry(),
        sourceAccountMap = sourceAccountMap ?? const {};

  /// Proses satu notifikasi menjadi kandidat.
  /// Mengembalikan null bila notifikasi diabaikan (bukan transaksi).
  Future<TransactionCandidate?> process(
    RawNotification notif,
    AutoRecordSettings settings,
  ) async {
    // Parse deterministik per format sumber (tiket 10).
    final parsed = _parsers.parse(notif);
    if (parsed == null) return null;

    // failed/pending/refund → kandidat tetap dibuat agar policy
    // bisa memutuskan ignore dengan alasan jelas.
    var candidate = TransactionCandidate(
      sourceType: CandidateSourceType.androidNotification,
      sourceApp: notif.packageName,
      sourceReference:
          '${notif.packageName}:${notif.id}:${notif.postedAt.millisecondsSinceEpoch}',
      parsedPayload: {
        'transaction_type': parsed.transactionType,
        'amount': parsed.amount,
        if (parsed.merchant != null) 'merchant': parsed.merchant,
        'description': notif.text,
        'occurred_at': notif.postedAt.millisecondsSinceEpoch,
        // Nama akun default dari mapping sumber (tiket 09 setup).
        if (sourceAccountMap[notif.packageName] != null)
          'account_hint': sourceAccountMap[notif.packageName],
      },
      confidence: parsed.confidence,
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

}
