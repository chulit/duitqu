import 'package:csv/csv.dart';
import 'package:drift/native.dart';
import 'package:duitqu/src/data/backup_service.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/category.dart';
import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late schema.AppDatabase db;
  late BackupService backup;

  /// DB berisi: 2 akun, 12 kategori bawaan + 1 kustom, 3 transaksi
  /// (expense+item, income, transfer), total 2 item.
  Future<void> seed() async {
    final accounts = DriftAccountRepository(db);
    final categories = DriftCategoryRepository(db);
    final txRepo = DriftTransactionRepository(db);
    final bca = await accounts.save(const Account(
        name: 'BCA', type: AccountType.bank, initialBalance: 1000000));
    final cash = await accounts.save(
        const Account(name: 'Cash', type: AccountType.cash));
    await categories.seedDefaults();
    final kopiId = await categories.save(const Category(name: 'Kopi'));
    final makanId = (await categories.defaults())
        .singleWhere((c) => c.name == 'Makan & Minum')
        .id!;
    final gajiId =
        (await categories.defaults()).singleWhere((c) => c.name == 'Gaji').id!;

    await txRepo.save(Transaction(
      type: TransactionType.expense,
      amount: 0, // dihitung dari item
      categoryId: makanId,
      accountId: bca,
      merchant: 'Indomaret, "Pusat"',
      date: DateTime(2026, 10, 15),
      note: 'belanja, mingguan\nbaris dua',
      createdAt: DateTime(2026, 10, 15),
      items: const [
        TransactionItem(name: 'Indomie', price: 3500, qty: 2),
        TransactionItem(name: 'Teh', price: 5000, qty: 1),
      ],
    ));
    await txRepo.save(Transaction(
      type: TransactionType.income,
      amount: 5000000,
      categoryId: gajiId,
      accountId: bca,
      date: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
    ));
    await txRepo.save(Transaction(
      type: TransactionType.transfer,
      amount: 200000,
      categoryId: kopiId, // kategori kustom pada transfer: aneh tapi valid
      accountId: bca,
      toAccountId: cash,
      date: DateTime(2026, 10, 10),
      createdAt: DateTime(2026, 10, 10),
    ));
  }

  setUp(() {
    db = schema.AppDatabase(NativeDatabase.memory());
    backup = BackupService(db);
  });

  tearDown(() => db.close());

  group('export', () {
    test('satu file memuat semua record', () async {
      await seed();
      final csv = await backup.exportCsv();
      // Hitung via decode (jangan split('\n'): field boleh mengandung newline
      // yang ter-quote).
      final rows = Csv().decode(csv);
      // tag + header + 2 akun + 13 kategori + 3 transaksi + 2 item
      expect(rows.length, 2 + 2 + 13 + 3 + 2);
      expect(rows[0][1], 'duitqu-backup-v1');
      expect(rows[1].first, 'record');
    });
  });

  group('round-trip', () {
    test('impor ke DB kosong mengembalikan semua data utuh', () async {
      await seed();
      final csv = await backup.exportCsv();

      final db2 = schema.AppDatabase(NativeDatabase.memory());
      final backup2 = BackupService(db2);
      final report = await backup2.importCsv(csv);

      expect(report.imported, 2 + 13 + 3 + 2);
      expect(report.skipped, isEmpty);

      final txs = await DriftTransactionRepository(db2)
          .list(const TransactionQuery());
      expect(txs, hasLength(3));

      // Item tertaut ke transaksi yang benar.
      final withItems = txs.singleWhere((t) => t.items.isNotEmpty);
      expect(withItems.amount, 3500 * 2 + 5000);
      expect(withItems.items.map((i) => i.name),
          containsAll(['Indomie', 'Teh']));

      // Karakter khusus (koma, kutip, newline) selamat.
      expect(withItems.merchant, 'Indomaret, "Pusat"');
      expect(withItems.note, 'belanja, mingguan\nbaris dua');

      // Transfer utuh dengan akun tertaut ulang.
      final transfer =
          txs.singleWhere((t) => t.type == TransactionType.transfer);
      expect(transfer.toAccountId, isNotNull);
      expect(transfer.toAccountId, isNot(transfer.accountId));

      // Saldo awal akun ikut.
      final accs = await DriftAccountRepository(db2).list();
      expect(
          accs.singleWhere((a) => a.name == 'BCA').initialBalance, 1000000);

      // Kategori bawaan tidak duplikat.
      final cats = await DriftCategoryRepository(db2).list();
      expect(cats.where((c) => c.isDefault), hasLength(12));
      expect(cats.singleWhere((c) => c.name == 'Kopi').isDefault, isFalse);

      await db2.close();
    });

    test('data lama tidak tertimpa; ID dipetakan ulang', () async {
      await seed();
      final csv = await backup.exportCsv();

      // DB tujuan sudah punya 1 akun + 1 transaksi sendiri.
      final db2 = schema.AppDatabase(NativeDatabase.memory());
      final accRepo2 = DriftAccountRepository(db2);
      final txRepo2 = DriftTransactionRepository(db2);
      final myAcc = await accRepo2.save(
          const Account(name: 'Milikku', type: AccountType.cash));
      await txRepo2.save(Transaction(
        type: TransactionType.expense,
        amount: 999,
        accountId: myAcc,
        date: DateTime(2026, 10, 15),
        createdAt: DateTime(2026, 10, 15),
      ));

      final report = await BackupService(db2).importCsv(csv);
      expect(report.skipped, isEmpty);

      final txs = await txRepo2.list(const TransactionQuery());
      expect(txs, hasLength(4)); // 1 lama + 3 impor
      expect(txs.where((t) => t.amount == 999), hasLength(1));
      // Item impor tertaut ke transaksi impor, bukan ke milik lama.
      final imported =
          txs.singleWhere((t) => t.items.isNotEmpty);
      expect(imported.id, isNot(999)); // id baru, bukan id lama
      await db2.close();
    });
  });

  group('baris rusak', () {
    test('dilewati per baris + alasan; yang valid tetap masuk', () async {
      await seed();
      var csv = await backup.exportCsv();
      // Rusak 1 baris transaksi: amount bukan angka.
      csv = csv.replaceFirst(
        RegExp(r'\ntransaction,(\d+),expense,,(\d+),'),
        '\ntransaction,\$1,expense,,BUKAN-ANGKA,',
      );
      // Tambah 1 baris record asing.
      csv += '\nalien,99,,,,,,,,,,,,,,,,,\n';

      final db2 = schema.AppDatabase(NativeDatabase.memory());
      final report = await BackupService(db2).importCsv(csv);

      expect(report.skipped.length, 4); // 1 transaksi + 2 itemnya + 1 alien
      expect(report.skipped.map((s) => s.reason),
          everyElement(isNotEmpty));
      expect(report.transactions, 2); // 1 rusak dilewati
      // Item milik transaksi rusak ikut dilewati (transaksi tak ada).
      expect(report.items, 0);

      await db2.close();
    });
  });

  group('file tidak valid', () {
    test('header asing -> BackupFormatException, tidak ada yang ditulis',
        () async {
      final db2 = schema.AppDatabase(NativeDatabase.memory());
      expect(
        () => BackupService(db2).importCsv('nama,umur\nBudi,30\n'),
        throwsA(isA<BackupFormatException>()),
      );
      final txs = await DriftTransactionRepository(db2)
          .list(const TransactionQuery());
      expect(txs, isEmpty);
      await db2.close();
    });

    test('file kosong -> BackupFormatException', () async {
      final db2 = schema.AppDatabase(NativeDatabase.memory());
      expect(
        () => BackupService(db2).importCsv(''),
        throwsA(isA<BackupFormatException>()),
      );
      await db2.close();
    });
  });
}
