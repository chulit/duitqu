import '../entities/transaction_candidate.dart';

/// Hasil parsing satu pesan chat menjadi kandidat transaksi.
///
/// [confidence] 0.0–1.0: seberapa yakin parser. Rendah → inbox review.
class ParsedChat {
  final String? transactionType; // income | expense | transfer
  final int? amount; // rupiah
  final String? merchant;
  final String? accountName; // nama akun disebut di teks
  final String? toAccountName; // untuk transfer
  final double confidence;

  const ParsedChat({
    this.transactionType,
    this.amount,
    this.merchant,
    this.accountName,
    this.toAccountName,
    this.confidence = 0.0,
  });
}

/// Parser chat → kandidat transaksi, deterministik (tiket 06, spec v2).
///
/// Pure Dart, tanpa AI. Menangani pola umum Bahasa Indonesia:
/// "makan siang 35 ribu pakai GoPay", "dapat gaji 5jt",
/// "transfer 500 ribu dari BCA ke GoPay".
///
/// Tidak pernah write ke database — hanya menghasilkan kandidat.
class TransactionParser {
  static final _expenseKeywords = [
    'keluar', 'bayar', 'beli', 'belanja', 'jajan', 'makan', 'minum',
    'isi', 'top.?up', 'topup', 'tarik',
  ];
  static final _incomeKeywords = [
    'masuk', 'dapat', 'terima', 'gaji', 'bonus', 'untung', 'cair',
  ];
  static final _transferKeywords = [
    'transfer', 'kirim', 'pindah',
  ];

  /// Parse teks menjadi kandidat. Selalu mengembalikan kandidat
  /// (confidence rendah bila ambigu) — tidak pernah null.
  TransactionCandidate parse(String text) {
    final parsed = parseChat(text);
    final payload = <String, dynamic>{
      if (parsed.transactionType != null)
        'transaction_type': parsed.transactionType,
      if (parsed.amount != null) 'amount': parsed.amount,
      if (parsed.merchant != null) 'merchant': parsed.merchant,
      if (parsed.accountName != null)
        'account_hint': parsed.accountName,
      if (parsed.toAccountName != null)
        'to_account_hint': parsed.toAccountName,
      'occurred_at': DateTime.now().millisecondsSinceEpoch,
      'raw_text': text,
    };
    return TransactionCandidate(
      sourceType: CandidateSourceType.chat,
      parsedPayload: payload,
      confidence: parsed.confidence,
      status: CandidateStatus.parsing,
      receivedAt: DateTime.now(),
    );
  }

  /// Parse murni tanpa membungkus kandidat (untuk testing).
  ParsedChat parseChat(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) {
      return const ParsedChat(confidence: 0.0);
    }

    final amount = _extractAmount(lower);
    final type = _classifyType(lower);
    final accounts = _extractAccounts(lower);
    final merchant = _extractMerchant(lower, amount);

    // Hitung confidence dari kelengkapan field.
    var score = 0.0;
    if (type != null) score += 0.35;
    if (amount != null) score += 0.35;
    if (merchant != null && merchant.isNotEmpty) score += 0.15;
    if (accounts.isNotEmpty) score += 0.15;
    // Bonus bila tipe + nominal lengkap (syarat minimal transaksi).
    if (type != null && amount != null) score += 0.1;

    return ParsedChat(
      transactionType: type,
      amount: amount,
      merchant: merchant,
      accountName: accounts.isNotEmpty ? accounts.first : null,
      toAccountName: accounts.length > 1 ? accounts[1] : null,
      confidence: score.clamp(0.0, 1.0),
    );
  }

  /// Ekstrak nominal: "35 ribu", "7 juta", "Rp28.000", "50rb", "1,5jt", "25k".
  int? _extractAmount(String lower) {
    // Pola: angka + satuan (ribu/rb/k/juta/jt) atau Rp + angka.
    final patterns = [
      RegExp(r'rp\s?([\d\.,]+)\s*(ribu|rb|k|juta|jt)?\b'),
      RegExp(r'([\d\.,]+)\s*(ribu|rb|k|juta|jt)\b'),
      RegExp(r'\b([\d\.,]+)\b'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(lower);
      if (m == null) continue;
      final numStr = m.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      final value = double.tryParse(numStr);
      if (value == null) continue;
      final unit =
          (m.groupCount >= 2 ? m.group(2) : null)?.toLowerCase() ?? '';
      final multiplier =
          (unit == 'juta' || unit == 'jt') ? 1000000 : 1;
      // Tanpa satuan eksplisit tapi ada "ribu/rb" terpisah sudah ditangani;
      // angka polos dianggap rupiah.
      final withRibu =
          (unit == 'ribu' || unit == 'rb' || unit == 'k') ? 1000 : 1;
      return (value * multiplier * withRibu).round();
    }
    return null;
  }

  /// Klasifikasi intent dari kata kunci.
  String? _classifyType(String lower) {
    for (final kw in _transferKeywords) {
      if (RegExp('\\b$kw\\b').hasMatch(lower)) return 'transfer';
    }
    for (final kw in _incomeKeywords) {
      if (RegExp('\\b$kw\\b').hasMatch(lower)) return 'income';
    }
    for (final kw in _expenseKeywords) {
      if (RegExp('\\b$kw\\b').hasMatch(lower)) return 'expense';
    }
    return null;
  }

  /// Ekstrak nama akun yang disebut, urut kemunculan di teks.
  List<String> _extractAccounts(String lower) {
    const known = [
      'gopay', 'ovo', 'dana', 'bca', 'bri', 'mandiri', 'bni',
      'cash', 'tunai', 'dompet',
    ];
    final found = <String, int>{};
    for (final a in known) {
      final m = RegExp('\\b$a\\b').firstMatch(lower);
      if (m != null) found[a] = m.start;
    }
    final sorted = found.keys.toList()
      ..sort((a, b) => found[a]!.compareTo(found[b]!));
    return sorted;
  }

  /// Merchant = sisa teks setelah buang nominal, keyword tipe, dan akun.
  String? _extractMerchant(String lower, int? amount) {
    var rest = lower;
    // Buang pola nominal.
    rest = rest.replaceAll(
      RegExp(r'rp\s?[\d\.,]+\s*(ribu|rb|k|juta|jt)?\b'),
      ' ',
    );
    rest = rest.replaceAll(
      RegExp(r'[\d\.,]+\s*(ribu|rb|k|juta|jt)\b'),
      ' ',
    );
    rest = rest.replaceAll(RegExp(r'\b[\d\.,]+\b'), ' ');
    // Buang keyword tipe + akun + kata sambung umum.
    const stopwords = [
      'keluar', 'bayar', 'beli', 'belanja', 'jajan', 'makan', 'minum',
      'masuk', 'dapat', 'terima', 'gaji', 'bonus',
      'transfer', 'kirim', 'pindah', 'dari', 'ke', 'pakai', 'pake',
      'dengan', 'buat', 'untuk', 'di', 'tadi', 'barusan', 'udah',
      'sudah', 'ya', 'sih', 'dong', 'nih', 'tu', 'itu', 'ini',
    ];
    for (final w in stopwords) {
      rest = rest.replaceAll(RegExp('\\b$w\\b'), ' ');
    }
    rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Buang nama akun yang terdeteksi.
    for (final a in _extractAccounts(lower)) {
      rest = rest.replaceAll(RegExp('\\b$a\\b'), ' ');
    }
    rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    return rest.isEmpty ? null : rest;
  }
}
