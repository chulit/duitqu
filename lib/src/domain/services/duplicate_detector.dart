import '../entities/transaction_candidate.dart';

/// Deteksi duplikat kandidat (tiket 03, spec v2 §7).
///
/// Pure Dart. Satu event yang diproses dua kali tidak boleh menghasilkan
/// dua transaksi — fingerprint yang sama berarti kandidat yang sama.
///
/// Strategi fingerprint:
/// 1. Bila sumber memberi reference ID → `ref:{sourceType}:{sourceApp}:{ref}`.
///    Reference sama dari sumber sama = event yang sama.
/// 2. Bila tidak → hash ternormalisasi dari
///    (sourceType, tipe, nominal, merchant, bucket waktu).
///    Bucket waktu 10 menit: dua notifikasi untuk pembelian yang sama
///    (datang berdekatan) dapat fingerprint sama, tapi dua pembelian
///    mirip di jam berbeda tetap beda.
class DuplicateDetector {
  /// Lebar bucket waktu untuk fingerprint konten (menit).
  static const int timeBucketMinutes = 10;

  /// Hitung fingerprint untuk kandidat.
  String fingerprint(TransactionCandidate c) {
    final ref = c.sourceReference;
    if (ref != null && ref.isNotEmpty) {
      return 'ref:${c.sourceType.name}:${c.sourceApp ?? ''}:$ref';
    }
    final p = c.parsedPayload;
    final type = (p['transaction_type'] as String? ?? 'expense').toLowerCase();
    final amount = p['amount']?.toString() ?? '0';
    final merchant = _normalizeMerchant(p['merchant'] as String?);
    final bucket = _timeBucket(_occurredAt(c, p));
    return 'c:${c.sourceType.name}:$type:$amount:$merchant:$bucket';
  }

  /// Apakah kandidat ini duplikat dari kandidat lain
  /// (fingerprint sama)?
  bool isDuplicate(TransactionCandidate a, TransactionCandidate b) =>
      fingerprint(a) == fingerprint(b);

  String _normalizeMerchant(String? merchant) {
    if (merchant == null) return '';
    return merchant.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  DateTime _occurredAt(TransactionCandidate c, Map<String, dynamic> p) {
    final raw = p['occurred_at'];
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return c.receivedAt;
  }

  String _timeBucket(DateTime dt) {
    final bucket = (dt.hour * 60 + dt.minute) ~/ timeBucketMinutes;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d-${bucket.toString().padLeft(3, '0')}';
  }
}
