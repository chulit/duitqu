import '../entities/transaction_candidate.dart';
import '../repositories/candidate_repository.dart';
import 'auto_record_policy.dart';
import 'duplicate_detector.dart';
import 'receipt_parser.dart';

/// Hasil capture struk (kontrak antara data layer dan service).
///
/// Didefinisikan di domain agar service bisa pure & testable;
/// implementasi konkret ada di `data/receipt_capture.dart`.
class ReceiptCaptureResult {
  final String? text;
  final bool cancelled;
  final bool modelNotReady;
  final String? error;

  const ReceiptCaptureResult._({
    this.text,
    this.cancelled = false,
    this.modelNotReady = false,
    this.error,
  });

  const ReceiptCaptureResult.text(String text)
      : this._(text: text);

  const ReceiptCaptureResult.cancelled() : this._(cancelled: true);

  const ReceiptCaptureResult.modelNotReady()
      : this._(modelNotReady: true);

  const ReceiptCaptureResult.error(String error)
      : this._(error: error);
}

/// Fungsi capture yang di-inject: produksi pakai [ReceiptCapture],
/// test pakai fake.
typedef ReceiptCaptureFn = Future<ReceiptCaptureResult> Function();

/// Hasil satu sesi scan struk.
class ReceiptScanOutcome {
  final TransactionCandidate? candidate;
  final bool cancelled;
  final bool modelNotReady;
  final String? error;

  const ReceiptScanOutcome._({
    this.candidate,
    this.cancelled = false,
    this.modelNotReady = false,
    this.error,
  });

  const ReceiptScanOutcome.ok(TransactionCandidate candidate)
      : this._(candidate: candidate);

  const ReceiptScanOutcome.cancelled() : this._(cancelled: true);

  const ReceiptScanOutcome.modelNotReady()
      : this._(modelNotReady: true);

  const ReceiptScanOutcome.error(String error) : this._(error: error);
}

/// Orkestrasi scan struk → kandidat (tiket 13, spec v2).
///
/// Alur: capture foto → OCR → parse → cek duplikat → evaluasi
/// kebijakan → simpan kandidat idempoten. Pure orchestration;
/// capture di-inject agar testable tanpa platform channel.
/// TransactionRepository TIDAK disentuh — kandidat menjadi transaksi
/// hanya via Inbox (write gate tetap).
class ReceiptScanService {
  final CandidateRepository _candidateRepo;
  final AutoRecordPolicy _policy;
  final DuplicateDetector _detector;
  final ReceiptParser _parser;
  final ReceiptCaptureFn _capture;

  ReceiptScanService(
    this._candidateRepo, {
    required this._capture,
    AutoRecordPolicy? policy,
    DuplicateDetector? detector,
    ReceiptParser? parser,
  })  : _policy = policy ?? AutoRecordPolicy(),
        _detector = detector ?? DuplicateDetector(),
        _parser = parser ?? ReceiptParser();

  Future<ReceiptScanOutcome> scan(AutoRecordSettings settings) async {
    final cap = await _capture();
    if (cap.cancelled) {
      return const ReceiptScanOutcome.cancelled();
    }
    if (cap.modelNotReady) {
      return const ReceiptScanOutcome.modelNotReady();
    }
    if (cap.text == null || cap.text!.trim().isEmpty) {
      return ReceiptScanOutcome.error(
        cap.error ?? 'Gagal membaca struk.',
      );
    }

    final parsed = _parser.parse(cap.text!);
    if (parsed == null) {
      return const ReceiptScanOutcome.error(
        'Nominal tidak terbaca dari struk.',
      );
    }

    var candidate = TransactionCandidate(
      sourceType: CandidateSourceType.receiptScan,
      sourceApp: 'camera',
      parsedPayload: {
        'transaction_type': 'expense',
        'amount': parsed.amount,
        if (parsed.merchant != null) 'merchant': parsed.merchant,
        'description': 'Scan struk'
            '${parsed.merchant != null ? ' ${parsed.merchant}' : ''}',
        'occurred_at': (parsed.date ?? DateTime.now())
            .millisecondsSinceEpoch,
      },
      confidence: parsed.confidence,
      status: CandidateStatus.parsing,
      receivedAt: DateTime.now(),
    );

    // Fingerprint + cek duplikat (scan ganda struk yang sama).
    final fp = _detector.fingerprint(candidate);
    candidate = candidate.copyWith(fingerprint: fp);
    final existing = await _candidateRepo.findByFingerprint(fp);
    final isDuplicate = existing != null;

    // Evaluasi kebijakan (tanpa account_id → needsReview 'Akun belum pasti').
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

    final id = await _candidateRepo.save(candidate);
    return ReceiptScanOutcome.ok(
      (await _candidateRepo.getById(id))!,
    );
  }
}
