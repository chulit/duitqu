import 'package:drift/drift.dart';

import '../database.dart' as db;
import '../../domain/entities/transaction.dart' as domain;
import '../../domain/repositories/transaction_repository.dart';

/// Adapter drift untuk [TransactionRepository] — SEAM UTAMA.
///
/// Menyembunyikan: query builder, join item, konsistensi amount-vs-item,
/// dan validasi input. Caller & test hanya kenal interface.
class DriftTransactionRepository implements TransactionRepository {
  final db.AppDatabase _db;

  DriftTransactionRepository(this._db);

  @override
  Future<int> save(domain.Transaction t) async {
    _validate(t);
    final amount = t.items.isEmpty
        ? t.amount
        : t.items.fold<int>(0, (s, i) => s + i.total);

    return _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final int id;
      if (t.id == null) {
        id = await _db
            .into(_db.transactions)
            .insert(
              db.TransactionsCompanion.insert(
                type: t.type.name,
                amount: amount,
                categoryId: Value(t.categoryId),
                accountId: t.accountId,
                toAccountId: Value(t.toAccountId),
                merchant: Value(t.merchant),
                date: t.date.millisecondsSinceEpoch,
                note: Value(t.note),
                createdAt: now,
                origin: Value(t.origin.name),
                sourceCandidateId: Value(t.sourceCandidateId),
                transferGroupId: Value(t.transferGroupId),
                receiptImagePath: Value(t.receiptImagePath),
              ),
            );
      } else {
        id = t.id!;
        await (_db.update(
          _db.transactions,
        )..where((tbl) => tbl.id.equals(id))).write(
          db.TransactionsCompanion(
            type: Value(t.type.name),
            amount: Value(amount),
            categoryId: Value(t.categoryId),
            accountId: Value(t.accountId),
            toAccountId: Value(t.toAccountId),
            merchant: Value(t.merchant),
            date: Value(t.date.millisecondsSinceEpoch),
            note: Value(t.note),
            origin: Value(t.origin.name),
            sourceCandidateId: Value(t.sourceCandidateId),
            transferGroupId: Value(t.transferGroupId),
            receiptImagePath: Value(t.receiptImagePath),
          ),
        );
        await (_db.delete(
          _db.transactionItems,
        )..where((tbl) => tbl.transactionId.equals(id))).go();
      }
      for (final item in t.items) {
        await _db
            .into(_db.transactionItems)
            .insert(
              db.TransactionItemsCompanion.insert(
                transactionId: id,
                name: item.name,
                price: item.price,
                qty: Value(item.qty),
              ),
            );
      }
      return id;
    });
  }

  @override
  Future<void> delete(int id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.transactionItems,
      )..where((tbl) => tbl.transactionId.equals(id))).go();
      await (_db.delete(
        _db.transactions,
      )..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  @override
  Future<List<domain.Transaction>> list(TransactionQuery q) async {
    final rows = await _filtered(q).get();
    return _withItems(rows);
  }

  @override
  Stream<List<domain.Transaction>> watch(TransactionQuery q) {
    // Watch tabel secara luas, terapkan filter penuh per emisi.
    // Sederhana & benar untuk skala data pribadi.
    final base = _db.select(_db.transactions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.id),
      ]);
    return base.watch().asyncMap((_) => list(q));
  }

  /// Saran merchant untuk autocomplete: unik, terbaru dulu.
  @override
  Future<List<String>> merchantSuggestions() async {
    final rows =
        await (_db.select(_db.transactions)
              ..where((t) => t.merchant.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    final seen = <String>{};
    final out = <String>[];
    for (final r in rows) {
      final m = r.merchant!;
      if (seen.add(m)) out.add(m);
    }
    return out;
  }

  // -- internal --

  void _validate(domain.Transaction t) {
    if (t.items.isEmpty && t.amount <= 0) {
      throw ArgumentError('Nominal harus lebih dari 0.');
    }
    for (final i in t.items) {
      if (i.name.trim().isEmpty) {
        throw ArgumentError('Nama item tidak boleh kosong.');
      }
      if (i.price < 0) {
        throw ArgumentError('Harga item tidak boleh negatif.');
      }
      if (i.qty <= 0) {
        throw ArgumentError('Qty item harus lebih dari 0.');
      }
    }
    if (t.type == domain.TransactionType.transfer) {
      if (t.toAccountId == null) {
        throw ArgumentError('Transfer wajib punya akun tujuan.');
      }
      if (t.toAccountId == t.accountId) {
        throw ArgumentError('Akun sumber dan tujuan tidak boleh sama.');
      }
    }
  }

  SimpleSelectStatement<db.$TransactionsTable, db.Transaction> _filtered(
    TransactionQuery q,
  ) {
    final query = _db.select(_db.transactions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (q.type != null) {
      query.where((t) => t.type.equals(q.type!.name));
    }
    if (q.accountId != null) {
      query.where(
        (t) =>
            t.accountId.equals(q.accountId!) |
            t.toAccountId.equals(q.accountId!),
      );
    }
    if (q.categoryId != null) {
      query.where((t) => t.categoryId.equals(q.categoryId!));
    }
    if (q.merchant != null && q.merchant!.isNotEmpty) {
      query.where((t) => t.merchant.equals(q.merchant!));
    }
    if (q.dateFrom != null) {
      query.where(
        (t) => t.date.isBiggerOrEqualValue(q.dateFrom!.millisecondsSinceEpoch),
      );
    }
    if (q.dateTo != null) {
      query.where(
        (t) => t.date.isSmallerOrEqualValue(q.dateTo!.millisecondsSinceEpoch),
      );
    }
    return query;
  }

  Future<List<domain.Transaction>> _withItems(List<db.Transaction> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r.id).toList();
    final itemRows = await (_db.select(
      _db.transactionItems,
    )..where((i) => i.transactionId.isIn(ids))).get();
    final byTx = <int, List<domain.TransactionItem>>{};
    for (final ir in itemRows) {
      (byTx[ir.transactionId] ??= []).add(
        domain.TransactionItem(
          id: ir.id,
          transactionId: ir.transactionId,
          name: ir.name,
          price: ir.price,
          qty: ir.qty,
        ),
      );
    }
    return [for (final r in rows) _toDomain(r, byTx[r.id] ?? const [])];
  }

  /// Pencarian teks: catatan/merchant cocok LIKE, atau nama item cocok.
  Future<List<domain.Transaction>> search(String text) async {
    final s = '%${text.trim()}%';
    final direct =
        await (_db.select(_db.transactions)
              ..where((t) => t.note.like(s) | t.merchant.like(s))
              ..orderBy([
                (t) => OrderingTerm.desc(t.date),
                (t) => OrderingTerm.desc(t.id),
              ]))
            .get();
    final itemTxIds =
        await (_db.select(_db.transactionItems)..where((i) => i.name.like(s)))
            .get()
            .then((rs) => rs.map((r) => r.transactionId).toSet());
    final viaItems = itemTxIds.isEmpty
        ? <db.Transaction>[]
        : await (_db.select(
            _db.transactions,
          )..where((t) => t.id.isIn(itemTxIds))).get();
    final merged = <int, db.Transaction>{};
    for (final r in [...direct, ...viaItems]) {
      merged[r.id] = r;
    }
    final sorted = merged.values.toList()
      ..sort(
        (a, b) =>
            b.date != a.date ? b.date.compareTo(a.date) : b.id.compareTo(a.id),
      );
    return _withItems(sorted);
  }

  domain.Transaction _toDomain(
    db.Transaction r,
    List<domain.TransactionItem> items,
  ) => domain.Transaction(
    id: r.id,
    type: domain.TransactionType.values.byName(r.type),
    amount: r.amount,
    categoryId: r.categoryId,
    accountId: r.accountId,
    toAccountId: r.toAccountId,
    merchant: r.merchant,
    date: DateTime.fromMillisecondsSinceEpoch(r.date),
    note: r.note,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    items: items,
    origin: domain.TransactionOrigin.values.byName(r.origin),
    sourceCandidateId: r.sourceCandidateId,
    transferGroupId: r.transferGroupId,
    receiptImagePath: r.receiptImagePath,
  );
}
