/// Jenis transaksi. Transfer bukan pengeluaran (lihat ADR 0002).
enum TransactionType { income, expense, transfer }

/// Satu kejadian uang. Pure Dart — tanpa dependensi framework/database.
///
/// Invariant: bila [items] tidak kosong,
/// [amount] == sum(item.price * item.qty) (dijaga TransactionRepository).
class Transaction {
  final int? id;
  final TransactionType type;
  final int amount; // satuan terkecil mata uang
  final int? categoryId;
  final int accountId;
  /// Akun tujuan — hanya untuk transfer.
  final int? toAccountId;
  final String? merchant;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final List<TransactionItem> items;

  const Transaction({
    this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.accountId,
    this.toAccountId,
    this.merchant,
    required this.date,
    this.note,
    required this.createdAt,
    this.items = const [],
  });
}

/// Rincian satu produk dalam transaksi belanja (struk). Lihat ADR 0003.
class TransactionItem {
  final int? id;
  final int? transactionId;
  final String name;
  final int price; // satuan terkecil
  final int qty;

  const TransactionItem({
    this.id,
    this.transactionId,
    required this.name,
    required this.price,
    this.qty = 1,
  });

  int get total => price * qty;
}
