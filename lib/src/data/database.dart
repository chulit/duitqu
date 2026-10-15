import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Tipe akun: bank | cash | ewallet | other (lihat GLOSSARY.md: Akun).
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  // Saldo awal dalam satuan terkecil mata uang (rupiah untuk IDR).
  IntColumn get initialBalance => integer().named('initial_balance')();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF0E7C5B))();
  IntColumn get createdAt => integer().named('created_at')(); // epoch millis, diisi repository
}

/// Kategori bawaan (isDefault) + kustom.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('tag'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF0E7C5B))();
  BoolColumn get isDefault =>
      boolean().named('is_default').withDefault(const Constant(false))();
}

/// Satu kejadian uang: income | expense | transfer.
/// Transfer memakai accountId (sumber) + toAccountId (tujuan), bukan pengeluaran.
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // income | expense | transfer
  IntColumn get amount => integer()(); // satuan terkecil; == sum(item) bila ada item
  IntColumn get categoryId =>
      integer().named('category_id').nullable().references(Categories, #id)();
  IntColumn get accountId =>
      integer().named('account_id').references(Accounts, #id)();
  IntColumn get toAccountId =>
      integer().named('to_account_id').nullable().references(Accounts, #id)();
  TextColumn get merchant => text().nullable()();
  IntColumn get date => integer()(); // epoch millis
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().named('created_at')();
}

/// Rincian produk dalam satu transaksi belanja (struk). Opsional.
class TransactionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId =>
      integer().named('transaction_id').references(Transactions, #id)();
  TextColumn get name => text()();
  IntColumn get price => integer()(); // satuan terkecil
  IntColumn get qty => integer().withDefault(const Constant(1))();
}

@DriftDatabase(
  tables: [Accounts, Categories, Transactions, TransactionItems],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'duitqu.sqlite'));
    return NativeDatabase(file);
  });
}
