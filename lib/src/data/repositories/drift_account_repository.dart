import 'package:drift/drift.dart';

import '../database.dart' as db;
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';

/// Adapter drift untuk [AccountRepository].
///
/// Semua aritmetika saldo disembunyikan di balik interface ini;
/// caller hanya perlu tahu [balance].
class DriftAccountRepository implements AccountRepository {
  final db.AppDatabase _db;

  DriftAccountRepository(this._db);

  @override
  Future<int> save(Account account) async {
    if (account.id == null) {
      return _db.into(_db.accounts).insert(
            db.AccountsCompanion.insert(
              name: account.name,
              type: account.type.name,
              initialBalance: account.initialBalance,
              icon: Value(account.icon),
              color: Value(account.color),
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    }
    await (_db.update(_db.accounts)
          ..where((t) => t.id.equals(account.id!)))
        .write(
      db.AccountsCompanion(
        name: Value(account.name),
        type: Value(account.type.name),
        initialBalance: Value(account.initialBalance),
        icon: Value(account.icon),
        color: Value(account.color),
      ),
    );
    return account.id!;
  }

  @override
  Future<void> delete(int id) async {
    final used = await (_db.select(_db.transactions)
          ..where((t) => t.accountId.equals(id) | t.toAccountId.equals(id)))
        .get();
    if (used.isNotEmpty) {
      throw StateError(
        'Akun tidak bisa dihapus: masih memiliki ${used.length} transaksi. '
        'Pindahkan atau hapus transaksinya dulu.',
      );
    }
    await (_db.delete(_db.accounts)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<Account>> list() async {
    final rows = await (_db.select(_db.accounts)
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<int> balance(int accountId, {DateTime? upTo}) async {
    final account = await (_db.select(_db.accounts)
          ..where((t) => t.id.equals(accountId)))
        .getSingleOrNull();
    if (account == null) {
      throw StateError('Akun tidak ditemukan.');
    }

    var total = account.initialBalance;
    final query = _db.select(_db.transactions)
      ..where(
        (t) => t.accountId.equals(accountId) | t.toAccountId.equals(accountId),
      );
    if (upTo != null) {
      query.where(
        (t) => t.date.isSmallerOrEqualValue(upTo.millisecondsSinceEpoch),
      );
    }
    for (final tx in await query.get()) {
      switch (tx.type) {
        case 'income':
          total += tx.amount;
        case 'expense':
          total -= tx.amount;
        case 'transfer':
          if (tx.accountId == accountId) total -= tx.amount;
          if (tx.toAccountId == accountId) total += tx.amount;
      }
    }
    return total;
  }

  Account _toDomain(db.Account row) => Account(
        id: row.id,
        name: row.name,
        type: AccountType.values.byName(row.type),
        initialBalance: row.initialBalance,
        icon: row.icon,
        color: row.color,
      );
}
