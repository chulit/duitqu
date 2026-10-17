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
  IntColumn get createdAt =>
      integer().named('created_at')(); // epoch millis, diisi repository
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
  IntColumn get amount =>
      integer()(); // satuan terkecil; == sum(item) bila ada item
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
  // --- v2: pelacakan sumber (tiket 02) ---
  /// Asal transaksi: manual | chat | android_notification | receipt_scan | statement_import.
  TextColumn get origin => text().withDefault(const Constant('manual'))();

  /// ID kandidat sumber bila berasal dari auto-catat.
  IntColumn get sourceCandidateId => integer()
      .named('source_candidate_id')
      .nullable()
      .references(TransactionCandidates, #id)();

  /// Grup transfer: kedua sisi transfer berbagi nilai ini.
  TextColumn get transferGroupId =>
      text().named('transfer_group_id').nullable()();

  /// Path gambar struk di app-private storage (tiket chat-ai 07).
  TextColumn get receiptImagePath =>
      text().named('receipt_image_path').nullable()();
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

/// Kandidat transaksi hasil parsing (spec v2, tiket 01).
///
/// Terpisah dari [Transactions]: kandidat adalah data mentah hasil interpretasi
/// yang belum tentu menjadi transaksi finansial.
class TransactionCandidates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceType => text().named('source_type')();
  TextColumn get sourceApp => text().named('source_app').nullable()();
  TextColumn get sourceReference =>
      text().named('source_reference').nullable()();
  TextColumn get fingerprint => text().nullable().unique()();
  TextColumn get parsedPayload =>
      text().named('parsed_payload').withDefault(const Constant('{}'))();
  RealColumn get confidence => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('received'))();
  TextColumn get reviewReason => text().named('review_reason').nullable()();
  IntColumn get transactionId => integer()
      .named('transaction_id')
      .nullable()
      .references(Transactions, #id)();
  IntColumn get receivedAt => integer().named('received_at')();
  IntColumn get processedAt => integer().named('processed_at').nullable()();
}

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    TransactionItems,
    TransactionCandidates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(transactionCandidates);
      }
      if (from < 3) {
        await m.addColumn(transactions, transactions.origin);
        await m.addColumn(transactions, transactions.sourceCandidateId);
        await m.addColumn(transactions, transactions.transferGroupId);
      }
      if (from < 4) {
        await m.addColumn(transactions, transactions.receiptImagePath);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'duitqu.sqlite'));
    return NativeDatabase(file);
  });
}
