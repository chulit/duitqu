import '../entities/transaction.dart';

/// Ringkasan agregat untuk satu periode.
class Summary {
  final int income;
  final int expense;
  final int count;

  const Summary({this.income = 0, this.expense = 0, this.count = 0});

  /// Selisih bersih. Transfer tidak masuk hitungan (bukan pemasukan
  /// maupun pengeluaran) — sesuai ADR 0002.
  int get net => income - expense;

  Summary operator +(Summary other) => Summary(
        income: income + other.income,
        expense: expense + other.expense,
        count: count + other.count,
      );
}

/// Agregasi murni (pure Dart, tanpa dependensi framework/database).
/// Semua logika "transfer bukan belanja" hidup di sini.
class SummaryService {
  const SummaryService();

  /// Ringkas daftar transaksi. Transfer dikecualikan dari income/expense.
  Summary summarize(Iterable<Transaction> txs) {
    var income = 0;
    var expense = 0;
    var count = 0;
    for (final tx in txs) {
      switch (tx.type) {
        case TransactionType.income:
          income += tx.amount;
          count++;
        case TransactionType.expense:
          expense += tx.amount;
          count++;
        case TransactionType.transfer:
          break; // bukan pemasukan maupun pengeluaran
      }
    }
    return Summary(income: income, expense: expense, count: count);
  }

  /// Rincian pengeluaran per kategori (categoryId -> total).
  /// Hanya tipe expense; transfer dikecualikan.
  Map<int, int> expenseByCategory(Iterable<Transaction> txs) {
    final out = <int, int>{};
    for (final tx in txs) {
      if (tx.type != TransactionType.expense) continue;
      final catId = tx.categoryId;
      if (catId == null) continue;
      out[catId] = (out[catId] ?? 0) + tx.amount;
    }
    return out;
  }

  /// Filter rentang tanggal inklusif (pure, untuk testing & UI).
  List<Transaction> inRange(
    Iterable<Transaction> txs,
    DateTime from,
    DateTime to,
  ) =>
      txs
          .where((t) =>
              !t.date.isBefore(from) &&
              t.date.isBefore(to.add(const Duration(days: 1))))
          .toList();

  /// Pencarian teks: catatan, merchant, atau nama item (case-insensitive).
  List<Transaction> search(Iterable<Transaction> txs, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return txs.toList();
    return txs.where((t) {
      if ((t.note ?? '').toLowerCase().contains(q)) return true;
      if ((t.merchant ?? '').toLowerCase().contains(q)) return true;
      return t.items.any((i) => i.name.toLowerCase().contains(q));
    }).toList();
  }
}
