import 'package:csv/csv.dart';
import 'package:drift/drift.dart';

import 'database.dart' as db;

/// Error level file: file bukan backup DuitQu yang valid.
/// Tidak ada satu baris pun yang ditulis bila ini dilempar.
class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this.message);
  @override
  String toString() => 'BackupFormatException: $message';
}

/// Satu baris yang dilewati saat impor, beserta alasannya.
class SkippedRow {
  final int row;
  final String reason;
  const SkippedRow({required this.row, required this.reason});
}

/// Hasil impor: yang berhasil per jenis + yang dilewati per baris.
class ImportReport {
  final int accounts;
  final int categories;
  final int transactions;
  final int items;
  final List<SkippedRow> skipped;

  const ImportReport({
    this.accounts = 0,
    this.categories = 0,
    this.transactions = 0,
    this.items = 0,
    this.skipped = const [],
  });

  int get imported => accounts + categories + transactions + items;
}

/// Backup manual v1: satu file CSV untuk seluruh data.
///
/// Format: satu tabel dengan kolom `record` sebagai diskriminator
/// (account|category|transaction|item). ID lama hanya dipakai untuk
/// menautkan item→transaksi saat impor, lalu dipetakan ke ID baru —
/// data yang sudah ada TIDAK PERNAH ditimpa atau dihapus (rule 14).
class BackupService {
  final db.AppDatabase _db;

  BackupService(this._db);

  static const _header = [
    'record',
    'id',
    'type',
    'name',
    'amount',
    'price',
    'qty',
    'account_id',
    'to_account_id',
    'category_id',
    'transaction_id',
    'merchant',
    'date',
    'note',
    'initial_balance',
    'icon',
    'color',
    'is_default',
  ];

  static const _appTag = 'duitqu-backup-v1';

  /// Ekspor seluruh data menjadi satu string CSV.
  Future<String> exportCsv() async {
    final rows = <List<dynamic>>[
      ['#', _appTag],
      _header,
    ];

    final accounts = await (_db.select(_db.accounts)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    for (final a in accounts) {
      rows.add([
        'account', a.id, a.type, a.name, '', '', '', '', '', '', '', '', '',
        '', a.initialBalance, a.icon, a.color, '',
      ]);
    }

    final categories = await (_db.select(_db.categories)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    for (final c in categories) {
      rows.add([
        'category', c.id, '', c.name, '', '', '', '', '', '', '', '', '', '',
        '', c.icon, c.color, c.isDefault ? '1' : '',
      ]);
    }

    final txs = await (_db.select(_db.transactions)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    for (final t in txs) {
      rows.add([
        'transaction', t.id, t.type, '', t.amount, '', '', t.accountId,
        t.toAccountId ?? '', t.categoryId ?? '', '', t.merchant ?? '',
        t.date, t.note ?? '', '', '', '', '',
      ]);
    }

    final items = await (_db.select(_db.transactionItems)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    for (final i in items) {
      rows.add([
        'item', i.id, '', i.name, '', i.price, i.qty, '', '', '',
        i.transactionId, '', '', '', '', '', '', '',
      ]);
    }

    return Csv().encode(rows);
  }

  /// Impor dari string CSV. Validasi dulu, tulis kemudian — atomik.
  ///
  /// - File tidak valid → [BackupFormatException], tidak ada yang ditulis.
  /// - Baris rusak → dilewati, tercatat di [ImportReport.skipped].
  /// - ID lama dipetakan ke ID baru; data lama tidak disentuh.
  Future<ImportReport> importCsv(String csv) async {
    final rows = _parse(csv);
    final parsed = <_Row>[];
    final skipped = <SkippedRow>[];
    for (var n = 2; n < rows.length; n++) {
      // n = nomor baris 1-based (baris 1 = tag, baris 2 = header)
      final cells = rows[n];
      if (cells.every((c) => c.toString().trim().isEmpty)) continue;
      try {
        parsed.add(_parseRow(n + 1, cells));
      } on _RowError catch (e) {
        skipped.add(SkippedRow(row: n + 1, reason: e.message));
      }
    }

    var accounts = 0, categories = 0, transactions = 0, items = 0;
    await _db.transaction(() async {
      final accountMap = <int, int>{};
      for (final p in parsed.whereType<_AccountRow>()) {
        final newId = await _db.into(_db.accounts).insert(
              db.AccountsCompanion.insert(
                name: p.name,
                type: p.type,
                initialBalance: p.initialBalance,
                icon: Value(p.icon),
                color: Value(p.color),
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
        accountMap[p.oldId] = newId;
        accounts++;
      }

      final categoryMap = <int, int>{};
      final existingDefaults =
          await (_db.select(_db.categories)..where((t) => t.isDefault.equals(true)))
              .get();
      final defaultByName = {for (final d in existingDefaults) d.name: d.id};
      for (final p in parsed.whereType<_CategoryRow>()) {
        if (p.isDefault && defaultByName.containsKey(p.name)) {
          // Kategori bawaan sudah ada — tautkan, jangan duplikat.
          categoryMap[p.oldId] = defaultByName[p.name]!;
          categories++;
          continue;
        }
        final newId = await _db.into(_db.categories).insert(
              db.CategoriesCompanion.insert(
                name: p.name,
                icon: Value(p.icon),
                color: Value(p.color),
                // Pertahankan flag bawaan bila DB tujuan belum punya —
                // round-trip ke DB kosong tetap utuh.
                isDefault: Value(p.isDefault),
              ),
            );
        categoryMap[p.oldId] = newId;
        categories++;
      }

      final txMap = <int, int>{};
      for (final p in parsed.whereType<_TransactionRow>()) {
        final accountId = accountMap[p.accountId];
        if (accountId == null) {
          skipped.add(SkippedRow(
              row: p.row,
              reason: 'akun ${p.accountId} tidak ada di file backup'));
          continue;
        }
        final toAccountId =
            p.toAccountId == null ? null : accountMap[p.toAccountId];
        if (p.toAccountId != null && toAccountId == null) {
          skipped.add(SkippedRow(
              row: p.row,
              reason: 'akun tujuan ${p.toAccountId} tidak ada di file backup'));
          continue;
        }
        final categoryId =
            p.categoryId == null ? null : categoryMap[p.categoryId];
        if (p.categoryId != null && categoryId == null) {
          skipped.add(SkippedRow(
              row: p.row,
              reason: 'kategori ${p.categoryId} tidak ada di file backup'));
          continue;
        }
        final newId = await _db.into(_db.transactions).insert(
              db.TransactionsCompanion.insert(
                type: p.type,
                amount: p.amount,
                categoryId: Value(categoryId),
                accountId: accountId,
                toAccountId: Value(toAccountId),
                merchant: Value(p.merchant),
                date: p.date,
                note: Value(p.note),
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
        txMap[p.oldId] = newId;
        transactions++;
      }

      for (final p in parsed.whereType<_ItemRow>()) {
        final txId = txMap[p.transactionId];
        if (txId == null) {
          skipped.add(SkippedRow(
              row: p.row,
              reason:
                  'transaksi ${p.transactionId} tidak ada di file backup'));
          continue;
        }
        await _db.into(_db.transactionItems).insert(
              db.TransactionItemsCompanion.insert(
                transactionId: txId,
                name: p.name,
                price: p.price,
                qty: Value(p.qty),
              ),
            );
        items++;
      }
    });

    return ImportReport(
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      items: items,
      skipped: skipped,
    );
  }

  // -- parsing & validasi --

  List<List<dynamic>> _parse(String csv) {
    late List<List<dynamic>> rows;
    try {
      rows = Csv().decode(csv);
    } catch (e) {
      throw BackupFormatException('File bukan CSV yang valid.');
    }
    if (rows.length < 2) {
      throw BackupFormatException('File kosong atau terpotong.');
    }
    final tag = rows[0].map((c) => c.toString()).toList();
    if (tag.length < 2 || tag[0] != '#' || tag[1] != _appTag) {
      throw BackupFormatException(
          'Bukan file backup DuitQu (tag tidak cocok).');
    }
    final header = rows[1].map((c) => c.toString()).toList();
    if (header.length != _header.length ||
        !_iterEquals(header, _header)) {
      throw BackupFormatException(
          'Header tidak dikenali — mungkin versi backup berbeda.');
    }
    return rows;
  }

  bool _iterEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _cell(List<dynamic> cells, int i) =>
      i < cells.length ? cells[i].toString().trim() : '';

  int _int(String v, String field, int row) {
    final n = int.tryParse(v);
    if (n == null) throw _RowError('kolom $field bukan angka: "$v"');
    return n;
  }

  _Row _parseRow(int row, List<dynamic> cells) {
    if (cells.length > _header.length) {
      throw _RowError('kelebihan kolom (${cells.length} > ${_header.length})');
    }
    final record = _cell(cells, 0);
    final id = _int(_cell(cells, 1), 'id', row);
    switch (record) {
      case 'account':
        final type = _cell(cells, 2);
        const valid = {'bank', 'cash', 'e_wallet', 'other'};
        if (!valid.contains(type)) {
          throw _RowError('tipe akun tidak dikenal: "$type"');
        }
        final name = _cell(cells, 3);
        if (name.isEmpty) throw _RowError('nama akun kosong');
        return _AccountRow(
          row: row,
          oldId: id,
          type: type,
          name: name,
          initialBalance: _int(_cell(cells, 14), 'initial_balance', row),
          icon: _cell(cells, 15),
          color: _int(_cell(cells, 16), 'color', row),
        );
      case 'category':
        final name = _cell(cells, 3);
        if (name.isEmpty) throw _RowError('nama kategori kosong');
        return _CategoryRow(
          row: row,
          oldId: id,
          name: name,
          icon: _cell(cells, 15),
          color: _int(_cell(cells, 16), 'color', row),
          isDefault: _cell(cells, 17) == '1',
        );
      case 'transaction':
        final type = _cell(cells, 2);
        const valid = {'income', 'expense', 'transfer'};
        if (!valid.contains(type)) {
          throw _RowError('tipe transaksi tidak dikenal: "$type"');
        }
        final amount = _int(_cell(cells, 4), 'amount', row);
        if (amount <= 0) throw _RowError('amount harus > 0');
        final toRaw = _cell(cells, 8);
        if (type == 'transfer' && toRaw.isEmpty) {
          throw _RowError('transfer tanpa akun tujuan');
        }
        return _TransactionRow(
          row: row,
          oldId: id,
          type: type,
          amount: amount,
          accountId: _int(_cell(cells, 7), 'account_id', row),
          toAccountId:
              toRaw.isEmpty ? null : _int(toRaw, 'to_account_id', row),
          categoryId: _cell(cells, 9).isEmpty
              ? null
              : _int(_cell(cells, 9), 'category_id', row),
          merchant: _cell(cells, 11).isEmpty ? null : _cell(cells, 11),
          date: _int(_cell(cells, 12), 'date', row),
          note: _cell(cells, 13).isEmpty ? null : _cell(cells, 13),
        );
      case 'item':
        final name = _cell(cells, 3);
        if (name.isEmpty) throw _RowError('nama item kosong');
        final price = _int(_cell(cells, 5), 'price', row);
        if (price < 0) throw _RowError('price negatif');
        final qty = _int(_cell(cells, 6), 'qty', row);
        if (qty <= 0) throw _RowError('qty harus > 0');
        return _ItemRow(
          row: row,
          oldId: id,
          name: name,
          price: price,
          qty: qty,
          transactionId: _int(_cell(cells, 10), 'transaction_id', row),
        );
      default:
        throw _RowError('tipe record tidak dikenal: "$record"');
    }
  }
}

class _RowError implements Exception {
  final String message;
  _RowError(this.message);
}

sealed class _Row {
  final int row;
  final int oldId;
  _Row({required this.row, required this.oldId});
}

class _AccountRow extends _Row {
  final String type, name, icon;
  final int initialBalance, color;
  _AccountRow({
    required super.row,
    required super.oldId,
    required this.type,
    required this.name,
    required this.initialBalance,
    required this.icon,
    required this.color,
  });
}

class _CategoryRow extends _Row {
  final String name, icon;
  final int color;
  final bool isDefault;
  _CategoryRow({
    required super.row,
    required super.oldId,
    required this.name,
    required this.icon,
    required this.color,
    required this.isDefault,
  });
}

class _TransactionRow extends _Row {
  final String type;
  final int amount, accountId, date;
  final int? toAccountId, categoryId;
  final String? merchant, note;
  _TransactionRow({
    required super.row,
    required super.oldId,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.date,
    this.toAccountId,
    this.categoryId,
    this.merchant,
    this.note,
  });
}

class _ItemRow extends _Row {
  final String name;
  final int price, qty, transactionId;
  _ItemRow({
    required super.row,
    required super.oldId,
    required this.name,
    required this.price,
    required this.qty,
    required this.transactionId,
  });
}
