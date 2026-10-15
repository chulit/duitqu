import 'dart:convert';

/// Status pemrosesan kandidat (lihat spec v2 §5.1).
///
/// Status kandidat dipisahkan dari status transaksi finansial. Kandidat yang
/// disimpan menjadi transaksi memiliki referensi ke record transaksi tersebut
/// via [TransactionCandidate.transactionId].
enum CandidateStatus {
  received,
  parsing,
  needsReview,
  readyToSave,
  saved,
  duplicate,
  ignored,
  failed,
}

/// Sumber input kandidat (lihat spec v2 §8.3).
enum CandidateSourceType {
  manual,
  chat,
  androidNotification,
  receiptScan,
  statementImport,
}

/// Satu kandidat transaksi hasil parsing — belum tentu menjadi transaksi.
///
/// Pure Dart — tanpa dependensi framework/database. Kandidat adalah data
/// mentah hasil interpretasi (notifikasi/chat/dokumen); hanya yang lolos
/// validasi domain dan kebijakan auto-catat yang menjadi [Transaction].
class TransactionCandidate {
  final int? id;
  final CandidateSourceType sourceType;

  /// Aplikasi sumber, mis. "com.gojek.gopay" untuk notifikasi. Null untuk chat.
  final String? sourceApp;

  /// Reference ID dari sumber (mis. ID transaksi di notifikasi). Dipakai
  /// untuk deduplikasi — null bila sumber tidak menyediakannya.
  final String? sourceReference;

  /// Fingerprint ternormalisasi untuk duplicate detection (lihat tiket 03).
  final String? fingerprint;

  /// Hasil parsing sebagai map: transaction_type, amount, currency, merchant,
  /// description, account_id, category_id, occurred_at (epoch millis), dll.
  /// Field wajib yang tidak tersedia TIDAK BOLEH diisi tebakan.
  final Map<String, dynamic> parsedPayload;

  /// Kualitas hasil parsing (0.0–1.0). Sinyal kualitas, bukan satu-satunya
  /// syarat auto-save (lihat AutoRecordPolicy, tiket 04).
  final double confidence;

  final CandidateStatus status;

  /// Alasan perlu review — diisi bila status == needsReview.
  final String? reviewReason;

  /// ID transaksi final bila kandidat sudah disimpan.
  final int? transactionId;

  final DateTime receivedAt;
  final DateTime? processedAt;

  const TransactionCandidate({
    this.id,
    required this.sourceType,
    this.sourceApp,
    this.sourceReference,
    this.fingerprint,
    this.parsedPayload = const {},
    this.confidence = 0.0,
    this.status = CandidateStatus.received,
    this.reviewReason,
    this.transactionId,
    required this.receivedAt,
    this.processedAt,
  });

  /// Salinan dengan field yang diubah (untuk transisi status).
  TransactionCandidate copyWith({
    int? id,
    CandidateSourceType? sourceType,
    String? sourceApp,
    String? sourceReference,
    String? fingerprint,
    Map<String, dynamic>? parsedPayload,
    double? confidence,
    CandidateStatus? status,
    String? reviewReason,
    int? transactionId,
    DateTime? receivedAt,
    DateTime? processedAt,
  }) {
    return TransactionCandidate(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceApp: sourceApp ?? this.sourceApp,
      sourceReference: sourceReference ?? this.sourceReference,
      fingerprint: fingerprint ?? this.fingerprint,
      parsedPayload: parsedPayload ?? this.parsedPayload,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      reviewReason: reviewReason ?? this.reviewReason,
      transactionId: transactionId ?? this.transactionId,
      receivedAt: receivedAt ?? this.receivedAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }

  /// Serialisasi payload untuk penyimpanan (JSON).
  static String encodePayload(Map<String, dynamic> payload) =>
      jsonEncode(payload);

  static Map<String, dynamic> decodePayload(String raw) {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }
}
