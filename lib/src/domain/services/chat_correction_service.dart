import '../entities/transaction.dart';

/// Jenis aksi koreksi via chat.
enum CorrectionAction {
  /// Ubah transaksi yang ada (mis. "ternyata 28 ribu, bukan 25 ribu").
  correct,

  /// Hapus transaksi (wajib konfirmasi eksplisit di UI).
  delete,
}

/// Hasil interpretasi perintah koreksi/hapus via chat.
class CorrectionCommand {
  final CorrectionAction action;

  /// Kata kunci merchant/deskripsi untuk resolusi konteks.
  final String? merchantHint;

  /// Nominal baru (untuk koreksi).
  final int? newAmount;

  /// Teks asli perintah.
  final String rawText;

  const CorrectionCommand({
    required this.action,
    this.merchantHint,
    this.newAmount,
    required this.rawText,
  });
}

/// Layanan koreksi & hapus via chat (tiket 07, spec v2).
///
/// Pure Dart. "Kopi tadi ternyata 28 ribu" → koreksi transaksi kopi
/// terakhir (bukan buat baru). "Hapus makan siang tadi" → hapus
/// dengan konfirmasi eksplisit di UI.
class ChatCorrectionService {
  static final _correctionKeywords = [
    'ternyata', 'ralat', 'koreksi', 'salah', 'bukan',
  ];
  static final _deleteKeywords = [
    'hapus', 'batalkan', 'batal',
  ];
  static final _contextKeywords = [
    'tadi', 'barusan', 'yang tadi', 'terakhir',
  ];

  /// Deteksi apakah teks adalah perintah koreksi/hapus.
  /// Null bila bukan perintah koreksi/hapus.
  CorrectionCommand? interpret(String text, TransactionParserAmount parseAmount) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return null;

    final isDelete =
        _deleteKeywords.any((kw) => RegExp('\\b$kw\\b').hasMatch(lower));
    final isCorrection = _correctionKeywords
        .any((kw) => RegExp('\\b$kw\\b').hasMatch(lower));

    if (!isDelete && !isCorrection) return null;

    final amount = parseAmount(lower);
    final merchantHint = _extractMerchantHint(lower);

    return CorrectionCommand(
      action: isDelete ? CorrectionAction.delete : CorrectionAction.correct,
      merchantHint: merchantHint,
      newAmount: isDelete ? null : amount,
      rawText: text,
    );
  }

  /// Cari transaksi yang dimaksud: cocokkan merchantHint, pilih yang
  /// terbaru. Null bila tidak ada yang cocok.
  Transaction? resolveTarget(
    CorrectionCommand cmd,
    List<Transaction> recent,
  ) {
    if (recent.isEmpty) return null;
    final hint = cmd.merchantHint;
    if (hint == null || hint.isEmpty) {
      // Tanpa hint: "yang tadi" → transaksi terakhir.
      return recent.first;
    }
    final hintLower = hint.toLowerCase();
    for (final tx in recent) {
      final m = (tx.merchant ?? '').toLowerCase();
      final n = (tx.note ?? '').toLowerCase();
      if (m.contains(hintLower) ||
          hintLower.contains(m) && m.isNotEmpty ||
          n.contains(hintLower)) {
        return tx;
      }
    }
    return null;
  }

  /// Ambil kata kunci merchant dari perintah (buang keyword aksi).
  String? _extractMerchantHint(String lower) {
    var rest = lower;
    for (final kw in [
      ..._correctionKeywords,
      ..._deleteKeywords,
      ..._contextKeywords,
      'catatan', 'transaksi', 'yang',
    ]) {
      rest = rest.replaceAll(RegExp('\\b$kw\\b'), ' ');
    }
    // Buang pola nominal.
    rest = rest.replaceAll(
      RegExp(r'rp\s?[\d\.,]+\s*(ribu|rb|juta|jt)?\b'),
      ' ',
    );
    rest = rest.replaceAll(
      RegExp(r'[\d\.,]+\s*(ribu|rb|juta|jt)\b'),
      ' ',
    );
    rest = rest.replaceAll(RegExp(r'\b[\d\.,]+\b'), ' ');
    rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    return rest.isEmpty ? null : rest;
  }
}

/// Fungsi ekstrak nominal (di-inject agar testable).
typedef TransactionParserAmount = int? Function(String text);
