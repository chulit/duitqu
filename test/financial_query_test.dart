import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/services/financial_query_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late schema.AppDatabase db;
  late DriftTransactionRepository txRepo;
  late DriftCategoryRepository categoryRepo;
  late FinancialQueryService queries;
  late int bcaId;
  late int makanId;

  setUp(() async {
    db = schema.AppDatabase(NativeDatabase.memory());
    txRepo = DriftTransactionRepository(db);
    categoryRepo = DriftCategoryRepository(db);
    queries = FinancialQueryService(txRepo, categoryRepo);
    bcaId = await DriftAccountRepository(db).save(
        const Account(name: 'BCA', type: AccountType.bank));
    await categoryRepo.seedDefaults();
    makanId = (await categoryRepo.defaults())
        .singleWhere((c) => c.name == 'Makan & Minum')
        .id!;
  });

  tearDown(() => db.close());

  Future<void> seed() async {
    final now = DateTime.now();
    await txRepo.save(Transaction(
      type: TransactionType.expense,
      amount: 35000,
      categoryId: makanId,
      accountId: bcaId,
      merchant: 'Kopi Kenangan',
      date: now,
      createdAt: now,
    ));
    await txRepo.save(Transaction(
      type: TransactionType.expense,
      amount: 50000,
      categoryId: makanId,
      accountId: bcaId,
      merchant: 'Warung Padang',
      date: now,
      createdAt: now,
    ));
    await txRepo.save(Transaction(
      type: TransactionType.income,
      amount: 5000000,
      accountId: bcaId,
      merchant: 'Gaji',
      date: now,
      createdAt: now,
    ));
  }

  group('interpretasi', () {
    test('"pengeluaran makan bulan ini berapa?" → query', () {
      final q = queries.interpret('pengeluaran makan bulan ini berapa?');
      expect(q, isNotNull);
      expect(q!.kind, QueryKind.expenseTotal);
      expect(q.categoryHint, contains('makan'));
    });

    test('perintah catat bukan query', () {
      expect(
        queries.interpret('catat makan 35 ribu'),
        isNull,
      );
    });

    test('teks biasa bukan query', () {
      expect(queries.interpret('halo apa kabar'), isNull);
    });
  });

  group('jawaban dari data', () {
    test('total pengeluaran makan bulan ini', () async {
      await seed();
      final q = queries
          .interpret('pengeluaran makan bulan ini berapa?')!;
      final ans = await queries.answer(q);
      expect(ans, contains('85'));
      expect(ans, contains('Rp'));
    });

    test('total pemasukan bulan ini', () async {
      await seed();
      final q =
          queries.interpret('total pemasukan bulan ini berapa?')!;
      final ans = await queries.answer(q);
      expect(ans, contains('5.000.000'));
    });

    test('tanpa data → nol', () async {
      final q = queries
          .interpret('pengeluaran makan bulan ini berapa?')!;
      final ans = await queries.answer(q);
      expect(ans, contains('Rp0'));
    });
  });
}
