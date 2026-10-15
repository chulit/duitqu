import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/repositories/transaction_repository.dart';
import 'package:duitqu/src/domain/services/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late schema.AppDatabase db;
  late DriftAccountRepository accounts;
  late DriftCategoryRepository categories;
  late DriftTransactionRepository txRepo;
  late TransferService service;
  late int bcaId;
  late int cashId;
  late int adminCatId;

  setUp(() async {
    db = schema.AppDatabase(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    categories = DriftCategoryRepository(db);
    txRepo = DriftTransactionRepository(db);
    service = TransferService(txRepo, categories);
    bcaId = await accounts.save(
        const Account(name: 'BCA', type: AccountType.bank));
    cashId = await accounts.save(
        const Account(name: 'Cash', type: AccountType.cash));
    await categories.seedDefaults();
    adminCatId = (await categories.defaults())
        .singleWhere((c) => c.name == 'Biaya Admin')
        .id!;
  });

  tearDown(() => db.close());

  Transaction makeTransfer({int amount = 500000}) => Transaction(
        type: TransactionType.transfer,
        amount: amount,
        accountId: bcaId,
        toAccountId: cashId,
        date: DateTime(2026, 10, 15),
        createdAt: DateTime(2026, 10, 15),
      );

  group('TransferService', () {
    test('transfer tanpa fee hanya mencatat 1 transaksi', () async {
      await service.saveTransfer(makeTransfer());

      final all = await txRepo.list(const TransactionQuery());
      expect(all, hasLength(1));
      expect(all.single.type, TransactionType.transfer);
    });

    test('transfer dengan fee otomatis mencatat expense Biaya Admin',
        () async {
      await service.saveTransfer(makeTransfer(), fee: 2500);

      final all = await txRepo.list(const TransactionQuery());
      expect(all, hasLength(2));

      final feeTx = all.singleWhere(
          (t) => t.type == TransactionType.expense);
      expect(feeTx.amount, 2500);
      expect(feeTx.categoryId, adminCatId);
      expect(feeTx.accountId, bcaId);
      expect(feeTx.note, contains('Biaya admin'));
    });

    test('saldo: sumber berkurang amount+fee, tujuan bertambah amount',
        () async {
      await service.saveTransfer(makeTransfer(amount: 500000), fee: 2500);

      expect(await accounts.balance(bcaId), -(500000 + 2500));
      expect(await accounts.balance(cashId), 500000);
    });

    test('transfer tidak dihitung sebagai pengeluaran', () async {
      await service.saveTransfer(makeTransfer(amount: 500000));

      // Tidak ada transaksi expense sama sekali.
      final expenses = await txRepo.list(
          const TransactionQuery(type: TransactionType.expense));
      expect(expenses, isEmpty);
    });

    test('fee negatif ditolak', () async {
      expect(() => service.saveTransfer(makeTransfer(), fee: -100),
          throwsA(isA<ArgumentError>()));
    });

    test('bukan transfer ditolak', () async {
      final expense = Transaction(
        type: TransactionType.expense,
        amount: 10000,
        accountId: bcaId,
        date: DateTime(2026, 10, 15),
        createdAt: DateTime(2026, 10, 15),
      );
      expect(() => service.saveTransfer(expense, fee: 100),
          throwsA(isA<ArgumentError>()));
    });

    test('edit transfer tidak menduplikat biaya admin', () async {
      final id = await service.saveTransfer(makeTransfer(), fee: 2500);
      final existing =
          (await txRepo.list(const TransactionQuery())).firstWhere(
              (t) => t.type == TransactionType.transfer);

      await service.saveTransfer(
        Transaction(
          id: id,
          type: existing.type,
          amount: 600000,
          accountId: existing.accountId,
          toAccountId: existing.toAccountId,
          date: existing.date,
          createdAt: existing.createdAt,
        ),
        fee: 9999, // diabaikan saat edit
      );

      final all = await txRepo.list(const TransactionQuery());
      expect(all, hasLength(2)); // transfer + 1 fee lama
      final feeTx =
          all.singleWhere((t) => t.type == TransactionType.expense);
      expect(feeTx.amount, 2500); // tidak berubah
    });
  });
}
