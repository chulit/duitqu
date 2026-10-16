/// Hasil parse struk deterministik (tiket 13, spec v2).
///
/// Pure Dart — tanpa dependensi framework. Field yang tidak bisa
/// diekstrak dengan yakin dibiarkan null; confidence mencerminkan
/// kelengkapan field.
class ParsedReceipt {
  /// Nama merchant/toko, bila terdeteksi.
  final String? merchant;

  /// Total bayar dalam rupiah, bila terdeteksi.
  final int? amount;

  /// Tanggal transaksi pada struk, bila terdeteksi.
  final DateTime? date;

  /// 0.0–1.0 berdasarkan kelengkapan field.
  final double confidence;

  const ParsedReceipt({
    this.merchant,
    this.amount,
    this.date,
    this.confidence = 0.0,
  });
}

/// Parser deterministik teks OCR struk belanja.
///
/// Strategi:
/// - Nominal: cari baris berisi kata TOTAL / GRAND TOTAL / TOTAL BAYAR /
///   JUMLAH, lalu ambil nominal Rp terbesar di baris itu (atau baris
///   berikutnya bila baris itu tidak memuat angka).
/// - Merchant: baris non-kosong pertama yang terlihat seperti nama toko
///   (bukan alamat/telepon, bukan deretan tanda).
/// - Tanggal: pola dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy.
///
/// Mengembalikan null bila tidak ada nominal yang meyakinkan — struk
/// tanpa total tidak boleh menjadi kandidat.
class ReceiptParser {
  static final _totalKeywords = RegExp(
    r'\b(total|grand\s*total|total\s*bayar|jumlah\s*bayar|tagihan)\b',
    caseSensitive: false,
  );

  static final _amountPattern = RegExp(
    r'(?:rp\.?\s?)?([\d\.]+(?:,\d{1,2})?)',
    caseSensitive: false,
  );

  static final _datePattern = RegExp(
    r'\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b',
  );

  /// Baris yang jelas BUKAN nama merchant.
  static final _nonMerchant = RegExp(
    r'^(jl\.?|jalan|telp|phone|tel|npwp|no\.?|kasir|cashier|struk|nota|receipt|terima kasih|thank|www\.|\+?\d[\d\s\-\(\)]{6,})$',
    caseSensitive: false,
  );

  ParsedReceipt? parse(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final amount = _extractTotal(lines);
    if (amount == null || amount <= 0) return null;

    final merchant = _extractMerchant(lines);
    final date = _extractDate(ocrText);

    var confidence = 0.4; // nominal saja
    if (merchant != null) confidence += 0.3;
    if (date != null) confidence += 0.2;
    // Bonus bila baris total eksplisit menyebut kata "total".
    if (_totalKeywords.hasMatch(ocrText)) confidence += 0.1;
    confidence = confidence.clamp(0.0, 1.0);

    return ParsedReceipt(
      merchant: merchant,
      amount: amount,
      date: date,
      confidence: confidence,
    );
  }

  /// Cari nominal total. Prioritas: baris ber-kata "total" → nominal di
  /// baris itu; bila tidak ada angka, cek baris berikutnya; fallback:
  /// nominal terbesar di seluruh teks.
  int? _extractTotal(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      if (!_totalKeywords.hasMatch(lines[i])) continue;
      final onLine = _amountOnLine(lines[i]);
      if (onLine != null) return onLine;
      if (i + 1 < lines.length) {
        final next = _amountOnLine(lines[i + 1]);
        if (next != null) return next;
      }
    }
    // Fallback: nominal terbesar (asumsi = total bayar).
    int? best;
    for (final line in lines) {
      final v = _amountOnLine(line);
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  /// Ambil nominal terbesar dari satu baris. Format Indonesia:
  /// "Rp 28.000", "28.000", "1.250.000,00".
  int? _amountOnLine(String line) {
    int? best;
    for (final m in _amountPattern.allMatches(line)) {
      final raw = m.group(1)!;
      // Abaikan angka kecil yang jelas bukan nominal (mis. nomor urut).
      final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length < 3) continue;
      final normalized =
          raw.replaceAll('.', '').replaceAll(',', '.');
      final value = double.tryParse(normalized);
      if (value == null) continue;
      final rupiah = value.round();
      if (best == null || rupiah > best) best = rupiah;
    }
    return best;
  }

  String? _extractMerchant(List<String> lines) {
    for (final line in lines.take(4)) {
      final cleaned = line
          .replaceAll(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
          .trim();
      if (cleaned.length < 3) continue;
      if (_nonMerchant.hasMatch(cleaned)) continue;
      // Abaikan baris yang isinya mayoritas angka.
      final letters =
          RegExp(r'[a-zA-Z]').allMatches(cleaned).length;
      if (letters < 3) continue;
      // Potong bila terlalu panjang (kemungkinan alamat).
      final name = cleaned.length > 40
          ? cleaned.substring(0, 40).trim()
          : cleaned;
      return name;
    }
    return null;
  }

  DateTime? _extractDate(String text) {
    final m = _datePattern.firstMatch(text);
    if (m == null) return null;
    var day = int.tryParse(m.group(1)!);
    var month = int.tryParse(m.group(2)!);
    var year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}
