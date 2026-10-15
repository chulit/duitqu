import '../entities/transaction_candidate.dart';

/// Keputusan kebijakan auto-catat.
enum PolicyDecision {
  /// Langsung simpan sebagai transaksi.
  autoSave,

  /// Masuk inbox untuk review manual.
  needsReview,

  /// Abaikan (mis. indikasi gagal/refund/pending).
  ignore,
}

/// Hasil evaluasi kebijakan.
class PolicyResult {
  final PolicyDecision decision;

  /// Alasan — wajib diisi untuk needsReview/ignore.
  final String? reason;

  const PolicyResult(this.decision, [this.reason]);
}

/// Pengaturan auto-catat (diubah user via UI).
class AutoRecordSettings {
  /// Master switch: bila mati, semua kandidat → needsReview.
  final bool enabled;

  /// Sumber yang diizinkan untuk auto-save.
  final Set<CandidateSourceType> allowedSources;

  /// Batas bawah confidence untuk auto-save (0.0–1.0).
  final double confidenceThreshold;

  const AutoRecordSettings({
    this.enabled = true,
    this.allowedSources = const {
      CandidateSourceType.androidNotification,
      CandidateSourceType.chat,
    },
    this.confidenceThreshold = 0.8,
  });

  AutoRecordSettings copyWith({
    bool? enabled,
    Set<CandidateSourceType>? allowedSources,
    double? confidenceThreshold,
  }) {
    return AutoRecordSettings(
      enabled: enabled ?? this.enabled,
      allowedSources: allowedSources ?? this.allowedSources,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
    );
  }
}

/// Mesin kebijakan: kandidat auto-save atau masuk inbox review
/// (tiket 04, spec v2).
///
/// Pure Dart. Auto-save HANYA bila semua syarat lolos:
/// sumber diizinkan, tipe dikenali, nominal valid, akun pasti,
/// bukan duplikat, bukan indikasi gagal/refund/pending,
/// confidence cukup. Selain itu → needsReview dengan alasan jelas.
class AutoRecordPolicy {
  /// Kata kunci status yang berarti transaksi tidak final.
  static const List<String> nonFinalKeywords = [
    'gagal',
    'failed',
    'pending',
    'refund',
    'dibatalkan',
    'cancelled',
    'canceled',
  ];

  PolicyResult evaluate(
    TransactionCandidate candidate,
    AutoRecordSettings settings, {
    bool isDuplicate = false,
  }) {
    // Master switch mati → semua ke review.
    if (!settings.enabled) {
      return const PolicyResult(
        PolicyDecision.needsReview,
        'Auto-catat nonaktif',
      );
    }

    // Sumber tidak diizinkan.
    if (!settings.allowedSources.contains(candidate.sourceType)) {
      return const PolicyResult(
        PolicyDecision.needsReview,
        'Sumber belum diizinkan untuk auto-catat',
      );
    }

    final p = candidate.parsedPayload;

    // Tipe tidak dikenali.
    final type = (p['transaction_type'] as String?)?.toLowerCase();
    if (type != 'income' && type != 'expense' && type != 'transfer') {
      return const PolicyResult(
        PolicyDecision.needsReview,
        'Tipe transaksi tidak dikenali',
      );
    }

    // Nominal tidak valid.
    final amount = p['amount'];
    if (amount is! num || amount <= 0) {
      return const PolicyResult(
        PolicyDecision.needsReview,
        'Nominal tidak valid',
      );
    }

    // Akun belum pasti.
    if (p['account_id'] == null) {
      return const PolicyResult(
        PolicyDecision.needsReview,
        'Akun belum pasti',
      );
    }

    // Duplikat → tandai, jangan simpan ganda.
    if (isDuplicate) {
      return const PolicyResult(
        PolicyDecision.ignore,
        'Duplikat dari transaksi yang sudah ada',
      );
    }

    // Indikasi gagal/refund/pending → abaikan.
    final desc =
        '${p['description'] ?? ''} ${p['status'] ?? ''}'.toLowerCase();
    for (final kw in nonFinalKeywords) {
      if (desc.contains(kw)) {
        return PolicyResult(
          PolicyDecision.ignore,
          'Indikasi "$kw" — bukan transaksi final',
        );
      }
    }

    // Confidence di bawah threshold → review.
    if (candidate.confidence < settings.confidenceThreshold) {
      return PolicyResult(
        PolicyDecision.needsReview,
        'Kepercayaan parsing rendah '
        '(${(candidate.confidence * 100).round()}%)',
      );
    }

    return const PolicyResult(PolicyDecision.autoSave);
  }
}
