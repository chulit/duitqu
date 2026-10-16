import '../../data/notification_bridge.dart';

/// Hasil parse notifikasi deterministik.
class ParsedNotification {
  /// expense | income | transfer | refund | pending | failed | unknown
  final String transactionType;
  final int amount;
  final String? merchant;
  final double confidence;

  const ParsedNotification({
    required this.transactionType,
    required this.amount,
    this.merchant,
    this.confidence = 0.0,
  });
}

/// Parser satu format notifikasi (per aplikasi sumber).
abstract class NotificationFormatParser {
  /// Apakah parser ini menangani package ini.
  bool canParse(String packageName);

  /// Parse notifikasi. Null bila format tidak dikenali.
  ParsedNotification? parse(RawNotification notif);
}

/// Ekstrak "Rp28.000" / "Rp 1.500.000" dari teks.
int? extractRupiah(String text) {
  final m = RegExp(
    r'rp\s?([\d\.,]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final numStr = m.group(1)!.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(numStr)?.round();
}

/// Parser notifikasi GoPay.
/// Contoh: "Pembayaran Rp28.000 di Kopi Kenangan berhasil"
class GoPayParser implements NotificationFormatParser {
  @override
  bool canParse(String packageName) =>
      packageName.toLowerCase().contains('gopay') ||
      packageName == 'com.gojek.gopay';

  @override
  ParsedNotification? parse(RawNotification notif) {
    final text = '${notif.title} ${notif.text}';
    final amount = extractRupiah(text);
    if (amount == null) return null;

    final lower = text.toLowerCase();
    String type = 'expense';
    double confidence = 0.7;
    if (lower.contains('terima') || lower.contains('masuk') ||
        lower.contains('top up berhasil') && lower.contains('dari')) {
      type = 'income';
    }
    if (lower.contains('gagal') || lower.contains('failed')) {
      return ParsedNotification(
        transactionType: 'failed',
        amount: amount,
        confidence: 0.9,
      );
    }
    if (lower.contains('refund') || lower.contains('dana kembali')) {
      return ParsedNotification(
        transactionType: 'refund',
        amount: amount,
        confidence: 0.9,
      );
    }

    // Merchant: "di Kopi Kenangan berhasil" → "Kopi Kenangan".
    String? merchant;
    final m = RegExp(
      r'\bdi\s+(.+?)\s+(berhasil|telah|pada)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (m != null) {
      merchant = m.group(1)!.trim();
      confidence = 0.85;
    }

    return ParsedNotification(
      transactionType: type,
      amount: amount,
      merchant: merchant,
      confidence: confidence,
    );
  }
}

/// Parser notifikasi BCA mobile / m-BCA.
/// Contoh: "Transfer Rp500.000 ke BCA 1234567890 berhasil"
class BcaParser implements NotificationFormatParser {
  @override
  bool canParse(String packageName) {
    final p = packageName.toLowerCase();
    return p.contains('bca') || p == 'com.bca';
  }

  @override
  ParsedNotification? parse(RawNotification notif) {
    final text = '${notif.title} ${notif.text}';
    final amount = extractRupiah(text);
    if (amount == null) return null;

    final lower = text.toLowerCase();
    if (lower.contains('gagal')) {
      return ParsedNotification(
        transactionType: 'failed',
        amount: amount,
        confidence: 0.9,
      );
    }

    String type = 'expense';
    String? merchant;
    double confidence = 0.7;

    if (lower.contains('transfer') || lower.contains('kirim')) {
      type = 'transfer';
      final m = RegExp(
        r'\bke\s+([A-Za-z ]+?)\s+\d',
        caseSensitive: false,
      ).firstMatch(text);
      if (m != null) {
        merchant = m.group(1)!.trim();
        confidence = 0.8;
      }
    } else if (lower.contains('terima') || lower.contains('masuk')) {
      type = 'income';
      confidence = 0.8;
    }

    return ParsedNotification(
      transactionType: type,
      amount: amount,
      merchant: merchant,
      confidence: confidence,
    );
  }
}

/// Parser generik: coba ekstrak nominal + tebak tipe.
/// Dipakai untuk aplikasi yang belum punya parser khusus.
class GenericParser implements NotificationFormatParser {
  @override
  bool canParse(String packageName) => true; // fallback terakhir

  @override
  ParsedNotification? parse(RawNotification notif) {
    final text = '${notif.title} ${notif.text}';
    final amount = extractRupiah(text);
    if (amount == null) return null;

    final lower = text.toLowerCase();
    if (lower.contains('gagal') || lower.contains('failed')) {
      return ParsedNotification(
        transactionType: 'failed',
        amount: amount,
        confidence: 0.8,
      );
    }
    if (lower.contains('pending') || lower.contains('diproses')) {
      return ParsedNotification(
        transactionType: 'pending',
        amount: amount,
        confidence: 0.8,
      );
    }

    final type = (lower.contains('terima') || lower.contains('masuk'))
        ? 'income'
        : 'expense';
    return ParsedNotification(
      transactionType: type,
      amount: amount,
      merchant: notif.title.isNotEmpty ? notif.title : null,
      confidence: 0.5, // rendah — masuk inbox review
    );
  }
}

/// Registry: coba parser khusus dulu, fallback ke generik.
class NotificationParserRegistry {
  final List<NotificationFormatParser> _parsers;

  NotificationParserRegistry([List<NotificationFormatParser>? parsers])
      : _parsers = parsers ??
            [
              GoPayParser(),
              BcaParser(),
              GenericParser(), // harus terakhir
            ];

  ParsedNotification? parse(RawNotification notif) {
    for (final p in _parsers) {
      if (!p.canParse(notif.packageName)) continue;
      final result = p.parse(notif);
      if (result != null) return result;
      // Parser khusus gagal → jangan fallback (format dikenal tapi aneh).
      if (p is! GenericParser) return null;
    }
    return null;
  }
}
