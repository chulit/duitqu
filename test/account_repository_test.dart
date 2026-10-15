import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:flutter_test/flutter_test.dart';

schema.AppDatabase _openTestDb() =>
    schema.AppDatabase(NativeDatabase.memory());

Future<int> _addAccount(
  DriftAccountRepository repo, {
  String name = 'BCA',
  AccountType type = AccountType.bank,
  int initialBalance = 0,
}) {
  return repo.save(
    Account(name: name, type: type, initialBalance: initialBalance),
  );
}

/// Insert transaksi mentah (TransactionRepository baru ada di tiket 04).
Future<void> _addTx(
  schema.AppDatabase db, {
  required String type,
  required int amount,
  required int accountId,
  int? toAccountId,
  DateTime? date,
}) {
  final epoch = (date ?? DateTime(2026, 10, 15)).millisecondsSinceEpoch;
  return db.into(db.transactions).insert(
        schema.TransactionsCompanion.insert(
          type: type,
          amount: amount,
          accountId: accountId,
          toAccountId: Value(toAccountId),
          date: epoch,
          createdAt: epoch,
        ),
      );
}

void main() {
  late schema.AppDatabase db;
  late DriftAccountRepository repo;

  setUp(() {
    db = _openTestDb();
    repo = DriftAccountRepository(db);
  });

  tearDown(() => db.close());

  group('CRUD akun', () {
    test('simpan lalu list mengembalikan akun yang benar', () async {
      await _addAccount(repo, name: 'BCA', initialBalance: 1000000);
      await _addAccount(repo,
          name: 'Cash', type: AccountType.cash, initialBalance: 50000);

      final accounts = await repo.list();
      expect(accounts.map((a) => a.name), ['BCA', 'Cash']);
      expect(accounts.first.initialBalance, 1000000);
      expect(accounts.first.type, AccountType.bank);
    });

    test('initialBalance default 0', () async {
      final id = await _addAccount(repo);
      final accounts = await repo.list();
      expect(accounts.singleWhere((a) => a.id == id).initialBalance, 0);
    });

    test('save dengan id meng-update, bukan duplikat', () async {
      final id = await _addAccount(repo, name: 'BCA');
      await repo.save(Account(id: id, name: 'BCA Baru', type: AccountType.bank));

      final accounts = await repo.list();
      expect(accounts, hasLength(1));
      expect(accounts.single.name, 'BCA Baru');
    });

    test('hapus akun kosong berhasil', () async {
      final id = await _addAccount(repo);
      await repo.delete(id);
      expect(await repo.list(), isEmpty);
    });

    test('hapus akun yang punya transaksi DITOLAK dengan pesan jelas',
        () async {
      final id = await _addAccount(repo);
      await _addTx(db, type: 'expense', amount: 20000, accountId: id);

      expect(
        () => repo.delete(id),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('masih memiliki 1 transaksi'),
        )),
      );
      // akun tetap ada
      expect(await repo.list(), hasLength(1));
    });

    test('hapus akun tujuan transfer juga ditolak', () async {
      final src = await _addAccount(repo, name: 'BCA');
      final dst = await _addAccount(repo, name: 'Cash');
      await _addTx(db,
          type: 'transfer', amount: 100000, accountId: src, toAccountId: dst);

      expect(() => repo.delete(dst), throwsA(isA<StateError>()));
    });
  });

  group('saldo', () {
    test('saldo = awal + income − expense ± transfer', () async {
      final bca = await _addAccount(repo, initialBalance: 1000000);
      final cash = await _addAccount(repo, name: 'Cash');

      await _addTx(db, type: 'income', amount: 5000000, accountId: bca);
      await _addTx(db, type: 'expense', amount: 150000, accountId: bca);
      await _addTx(db,
          type: 'transfer', amount: 200000, accountId: bca, toAccountId: cash);

      expect(await repo.balance(bca), 1000000 + 5000000 - 150000 - 200000);
      expect(await repo.balance(cash), 200000);
    });

    test('upTo mengabaikan transaksi setelah tanggal', () async {
      final bca = await _addAccount(repo);
      await _addTx(db,
          type: 'income',
          amount: 100000,
          accountId: bca,
          date: DateTime(2026, 10, 10));
      await _addTx(db,
          type: 'income',
          amount: 999999,
          accountId: bca,
          date: DateTime(2026, 10, 20));

      expect(await repo.balance(bca, upTo: DateTime(2026, 10, 15)), 100000);
      expect(await repo.balance(bca), 100000 + 999999);
    });

    test('balance akun yang tidak ada throw StateError', () async {
      expect(() => repo.balance(999), throwsA(isA<StateError>()));
    });
  });
}
