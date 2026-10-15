import '../domain/entities/transaction.dart';

/// Default cerdas untuk catat kilat (in-memory, per sesi):
/// akun & kategori terakhir dipakai. Tanggal selalu hari ini.
class QuickAddDefaults {
  int? lastAccountId;
  int? lastCategoryId;
  TransactionType lastType = TransactionType.expense;

  void remember({
    int? accountId,
    int? categoryId,
    required TransactionType type,
  }) {
    if (accountId != null) lastAccountId = accountId;
    if (categoryId != null) lastCategoryId = categoryId;
    lastType = type;
  }
}
