import 'package:intl/intl.dart';

import '../entities/transaction.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';

/// Jenis pertanyaan keuangan.
enum QueryKind {
  /// Total pengeluaran per kategori/periode.
  expenseTotal,

  /// Total pemasukan per periode.
  incomeTotal,

  /// Saldo akun.
  balance,
}

/// Pertanyaan keuangan yang terdeteksi.
class FinancialQuery {
  final QueryKind kind;
  final String? categoryHint;
  final DateTime from;
  final DateTime to;
  final String? accountHint;

  const FinancialQuery({
    required this.kind,
    this.categoryHint,
    required this.from,
    required this.to,
    this.accountHint,
  });
}

/// Tanya-jawab keuangan via chat (tiket 08, spec v2).
///
/// "Pengeluaran makan bulan ini berapa?" dijawab dari transaksi
/// tersimpan — bukan tebakan. Pure logic + repository; tidak pakai AI.
class FinancialQueryService {
  final TransactionRepository _txRepo;
  final CategoryRepository _categoryRepo;

  static final _queryKeywords = [
    'berapa', 'total', 'jumlah',
  ];

  FinancialQueryService(this._txRepo, this._categoryRepo);

  /// Deteksi apakah teks adalah pertanyaan keuangan.
  /// Null bila bukan pertanyaan (mis. perintah catat).
  FinancialQuery? interpret(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return null;

    final isQuestion = _queryKeywords
            .any((kw) => RegExp('\\b$kw\\b').hasMatch(lower)) ||
        lower.endsWith('?');
    if (!isQuestion) return null;

    // Jangan salah tangkap perintah catat ("catat makan 35 ribu berapa?" tidak ada).
    // Perintah catat punya nominal eksplisit + kata kerja catat.
    if (RegExp(r'\b(catat|tambah|input)\b').hasMatch(lower)) return null;

    final kind = _detectKind(lower);
    if (kind == null) return null;

    final period = _detectPeriod(lower);
    final categoryHint =
        kind == QueryKind.expenseTotal ? _extractCategoryHint(lower) : null;
    final accountHint =
        kind == QueryKind.balance ? _extractAccountHint(lower) : null;

    return FinancialQuery(
      kind: kind,
      categoryHint: categoryHint,
      from: period.$1,
      to: period.$2,
      accountHint: accountHint,
    );
  }

  /// Jawab pertanyaan dengan Bahasa Indonesia natural.
  Future<String> answer(FinancialQuery q) async {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    switch (q.kind) {
      case QueryKind.expenseTotal:
        final total = await _expenseTotal(q);
        final cat = q.categoryHint ?? 'semua kategori';
        final period = _periodLabel(q);
        return 'Pengeluaran $cat $period: ${formatter.format(total)}.';
      case QueryKind.incomeTotal:
        final total = await _incomeTotal(q);
        final period = _periodLabel(q);
        return 'Pemasukan $period: ${formatter.format(total)}.';
      case QueryKind.balance:
        // TODO: saldo per akun butuh AccountRepository — sementara total.
        return 'Saldo per akun belum didukung, coba tanya pengeluaran atau pemasukan.';
    }
  }

  QueryKind? _detectKind(String lower) {
    if (RegExp(r'\b(saldo)\b').hasMatch(lower)) return QueryKind.balance;
    if (RegExp(r'\b(pengeluaran|keluar|habis)\b').hasMatch(lower)) {
      return QueryKind.expenseTotal;
    }
    if (RegExp(r'\b(pemasukan|masuk|pendapatan)\b').hasMatch(lower)) {
      return QueryKind.incomeTotal;
    }
    return null;
  }

  /// (from, to) untuk periode yang disebut.
  (DateTime, DateTime) _detectPeriod(String lower) {
    final now = DateTime.now();
    if (RegExp(r'\b(hari ini)\b').hasMatch(lower)) {
      final start = DateTime(now.year, now.month, now.day);
      return (start, start.add(const Duration(days: 1)));
    }
    if (RegExp(r'\b(minggu ini)\b').hasMatch(lower)) {
      final start = now.subtract(Duration(days: now.weekday - 1));
      final s = DateTime(start.year, start.month, start.day);
      return (s, s.add(const Duration(days: 7)));
    }
    if (RegExp(r'\b(tahun ini)\b').hasMatch(lower)) {
      return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
    }
    // Default: bulan ini.
    return (DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1));
  }

  String _periodLabel(FinancialQuery q) {
    final now = DateTime.now();
    if (q.from.day == 1 &&
        q.to.month == now.month + 1 ||
        q.to.month == 1 && now.month == 12) {
      return 'bulan ini';
    }
    return 'periode ini';
  }

  String? _extractCategoryHint(String lower) {
    // Buang keyword query + periode, sisanya = hint kategori.
    var rest = lower.replaceAll('?', ' ');
    for (final w in [
      'pengeluaran', 'berapa', 'total', 'jumlah', 'bulan', 'ini',
      'minggu', 'hari', 'tahun', 'untuk', 'kategori',
    ]) {
      rest = rest.replaceAll(RegExp('\\b$w\\b'), ' ');
    }
    rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    return rest.isEmpty ? null : rest;
  }

  String? _extractAccountHint(String lower) {
    var rest = lower
        .replaceAll('?', ' ')
        .replaceAll(RegExp(r'\b(saldo|berapa|total|ini)\b'), ' ');
    rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    return rest.isEmpty ? null : rest;
  }

  Future<int> _expenseTotal(FinancialQuery q) async {
    final txs = await _txRepo.list(
      TransactionQuery(dateFrom: q.from, dateTo: q.to),
    );
    final categories = await _categoryRepo.list();
    final catById = {for (final c in categories) c.id: c};
    var total = 0;
    for (final tx in txs) {
      if (tx.type != TransactionType.expense) continue;
      if (q.categoryHint != null) {
        final catName =
            (catById[tx.categoryId]?.name ?? '').toLowerCase();
        if (!catName.contains(q.categoryHint!.toLowerCase()) &&
            !q.categoryHint!.toLowerCase().contains(catName)) {
          continue;
        }
      }
      total += tx.amount;
    }
    return total;
  }

  Future<int> _incomeTotal(FinancialQuery q) async {
    final txs = await _txRepo.list(
      TransactionQuery(dateFrom: q.from, dateTo: q.to),
    );
    var total = 0;
    for (final tx in txs) {
      if (tx.type == TransactionType.income) total += tx.amount;
    }
    return total;
  }
}
