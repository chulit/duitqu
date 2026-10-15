import '../entities/transaction.dart';

/// Filter siap pakai untuk query transaksi. Kompleksitas query
/// disembunyikan di balik interface ini (lihat codebase-design).
class TransactionQuery {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? accountId;
  final int? categoryId;
  final String? merchant;
  final String? search;
  final TransactionType? type;

  const TransactionQuery({
    this.dateFrom,
    this.dateTo,
    this.accountId,
    this.categoryId,
    this.merchant,
    this.search,
    this.type,
  });
}

/// SEAM UTAMA. Satu-satunya jalan bagi caller & test menuju data transaksi.
abstract class TransactionRepository {
  /// Insert atau update. Menjaga invariant amount-vs-item.
  Future<int> save(Transaction transaction);

  /// Hapus transaksi beserta item-nya sebagai satu unit.
  Future<void> delete(int id);

  Future<List<Transaction>> list(TransactionQuery query);

  /// Untuk UI reaktif.
  Stream<List<Transaction>> watch(TransactionQuery query);

  /// Saran merchant unik untuk autocomplete, terbaru dulu.
  Future<List<String>> merchantSuggestions();
}
