import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late schema.AppDatabase db;
  late DriftTransactionRepository repo;
  late int bcaId;
  late int cashId;
  late int makanId;

  setUp(() async {
    db = schema.AppDatabase(NativeDatabase.memory());
    repo = DriftTransactionRepository(db);
    final accounts = DriftAccountRepository(db);
    final cats = DriftCategoryRepository(db);
    bcaId = await accounts.save(
      const Account(name: 'BCA', type: AccountType.bank),
    );
    cashId = await accounts.save(
      const Account(name: 'Cash', type: AccountType.cash),
    );
    await cats.seedDefaults();
    makanId = (await cats.defaults())
        .singleWhere((c) => c.name == 'Makan & Minum')
        .id!;
  });

  tearDown(() => db.close());

  Transaction makeTx({
    TransactionType type = TransactionType.expense,
    int amount = 50000,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    String? merchant,
    String? note,
    DateTime? date,
    List<TransactionItem> items = const [],
    TransactionOrigin origin = TransactionOrigin.manual,
    int? sourceCandidateId,
  }) => Transaction(
    type: type,
    amount: amount,
    categoryId: categoryId ?? makanId,
    accountId: accountId ?? bcaId,
    toAccountId: toAccountId,
    merchant: merchant,
    note: note,
    date: date ?? DateTime(2026, 10, 15),
    createdAt: DateTime(2026, 10, 15),
    items: items,
    origin: origin,
    sourceCandidateId: sourceCandidateId,
  );

  group('save & invariant', () {
    test('simpan dan baca kembali utuh', () async {
      final id = await repo.save(
        makeTx(merchant: 'Indomaret A', note: 'jajan', amount: 75000),
      );
      final all = await repo.list(const TransactionQuery());
      expect(all, hasLength(1));
      final tx = all.single;
      expect(tx.id, id);
      expect(tx.merchant, 'Indomaret A');
      expect(tx.note, 'jajan');
      expect(tx.amount, 75000);
      expect(tx.accountId, bcaId);
    });

    test('total dihitung otomatis dari item', () async {
      await repo.save(
        makeTx(
          items: const [
            TransactionItem(name: 'Indomie', price: 3500, qty: 2),
            TransactionItem(name: 'Teh', price: 5000, qty: 1),
          ],
        ),
      );
      final tx = (await repo.list(const TransactionQuery())).single;
      expect(tx.amount, 3500 * 2 + 5000);
      expect(tx.items, hasLength(2));
    });

    test('update mengganti item lama', () async {
      final id = await repo.save(
        makeTx(items: const [TransactionItem(name: 'A', price: 1000, qty: 1)]),
      );
      final existing = (await repo.list(const TransactionQuery())).single;
      await repo.save(
        Transaction(
          id: id,
          type: existing.type,
          amount: 0,
          categoryId: existing.categoryId,
          accountId: existing.accountId,
          date: existing.date,
          createdAt: existing.createdAt,
          items: const [TransactionItem(name: 'B', price: 2000, qty: 3)],
        ),
      );
      final tx = (await repo.list(const TransactionQuery())).single;
      expect(tx.amount, 6000);
      expect(tx.items.single.name, 'B');
    });

    test('delete menghapus transaksi + item-nya', () async {
      final id = await repo.save(
        makeTx(items: const [TransactionItem(name: 'A', price: 1000, qty: 1)]),
      );
      await repo.delete(id);
      expect(await repo.list(const TransactionQuery()), isEmpty);
      final items = await (db.select(db.transactionItems)).get();
      expect(items, isEmpty);
    });

    test('validasi: nominal 0 tanpa item ditolak', () async {
      expect(() => repo.save(makeTx(amount: 0)), throwsA(isA<ArgumentError>()));
    });

    test('validasi: transfer tanpa tujuan / tujuan sama ditolak', () async {
      expect(
        () => repo.save(makeTx(type: TransactionType.transfer, amount: 10000)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.save(
          makeTx(
            type: TransactionType.transfer,
            amount: 10000,
            toAccountId: bcaId,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validasi: item qty 0 ditolak', () async {
      expect(
        () => repo.save(
          makeTx(
            items: const [TransactionItem(name: 'A', price: 1000, qty: 0)],
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('filter & urutan', () {
    test('riwayat urut tanggal terbaru dulu', () async {
      await repo.save(makeTx(date: DateTime(2026, 10, 10), amount: 1000));
      await repo.save(makeTx(date: DateTime(2026, 10, 15), amount: 2000));
      await repo.save(makeTx(date: DateTime(2026, 10, 12), amount: 3000));
      final amounts = (await repo.list(const TransactionQuery()))
          .map((t) => t.amount);
      expect(amounts, [2000, 3000, 1000]);
    });

    test('filter tipe, akun, kategori, merchant, tanggal', () async {
      await repo.save(
        makeTx(type: TransactionType.income, amount: 1000, merchant: 'Kantor'),
      );
      await repo.save(
        makeTx(
          type: TransactionType.expense,
          amount: 2000,
          accountId: cashId,
          merchant: 'Indomaret A',
          date: DateTime(2026, 10, 14),
        ),
      );

      expect(
        await repo.list(const TransactionQuery(type: TransactionType.income)),
        hasLength(1),
      );
      final byCash = await repo.list(TransactionQuery(accountId: cashId));
      expect(byCash, hasLength(1));
      expect(byCash.single.amount, 2000);
      final byMerchant = await repo.list(
        const TransactionQuery(merchant: 'Kantor'),
      );
      expect(byMerchant.single.amount, 1000);
      final byDate = await repo.list(
        TransactionQuery(
          dateFrom: DateTime(2026, 10, 14),
          dateTo: DateTime(2026, 10, 14, 23, 59),
        ),
      );
      expect(byDate.single.amount, 2000);
    });

    test('merchantSuggestions unik terbaru-dulu', () async {
      await repo.save(makeTx(merchant: 'Indomaret A'));
      await repo.save(
        makeTx(merchant: 'Alfamart', date: DateTime(2026, 10, 16)),
      );
      await repo.save(
        makeTx(merchant: 'Indomaret A', date: DateTime(2026, 10, 17)),
      );
      expect(await repo.merchantSuggestions(), ['Indomaret A', 'Alfamart']);
    });

    test('search menemukan via catatan, merchant, nama item', () async {
      await repo.save(makeTx(note: 'bayar parkir'));
      await repo.save(makeTx(merchant: 'Indomaret A'));
      await repo.save(
        makeTx(
          items: const [
            TransactionItem(name: 'Indomie Goreng', price: 3500, qty: 1),
          ],
        ),
      );

      expect(await repo.search('parkir'), hasLength(1));
      expect(await repo.search('Indomaret'), hasLength(1));
      expect(await repo.search('Indomie'), hasLength(1));
      expect(await repo.search('tidak ada'), isEmpty);
    });
  });

  group('pelacakan sumber (tiket 02)', () {
    test('transaksi manual tercatat dengan origin=manual', () async {
      final id = await repo.save(makeTx(amount: 50000));
      final got = (await repo.list(const TransactionQuery()))
          .singleWhere((t) => t.id == id);
      expect(got.origin, TransactionOrigin.manual);
      expect(got.sourceCandidateId, isNull);
      expect(got.transferGroupId, isNull);
    });

    test('origin non-manual tersimpan dan terbaca', () async {
      final tx = makeTx(
        amount: 25000,
        origin: TransactionOrigin.chat,
        sourceCandidateId: 42,
      );
      final id = await repo.save(tx);
      final got = (await repo.list(const TransactionQuery()))
          .singleWhere((t) => t.id == id);
      expect(got.origin, TransactionOrigin.chat);
      expect(got.sourceCandidateId, 42);
    });
  });

  group('watch', () {
    test('mengirim ulang saat data berubah', () async {
      final emissions = <List<Transaction>>[];
      final sub = repo.watch(const TransactionQuery()).listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.save(makeTx(amount: 111));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last.single.amount, 111);
    });
  });
}
