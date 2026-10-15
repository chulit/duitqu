import 'package:duitqu/src/data/database.dart';
import 'package:duitqu/src/domain/entities/account.dart' as domain;
import 'package:duitqu/src/domain/entities/transaction.dart' as domain_tx;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('skema database', () {
    test('memuat kelima tabel dengan nama yang benar', () {
      final db = AppDatabase();
      final names = db.allTables.map((t) => t.actualTableName).toSet();
      expect(names, {
        'accounts',
        'categories',
        'transactions',
        'transaction_items',
        'transaction_candidates',
      });
    });

    test('kolom-kolom kunci tersedia dengan nama yang benar', () {
      final db = AppDatabase();
      expect(db.transactions.amount.name, 'amount');
      expect(db.transactions.merchant.name, 'merchant');
      expect(db.transactions.toAccountId.name, 'to_account_id');
      expect(db.transactions.accountId.name, 'account_id');
      expect(db.accounts.initialBalance.name, 'initial_balance');
      expect(db.transactionItems.qty.name, 'qty');
      expect(db.transactionItems.transactionId.name, 'transaction_id');
    });

    test('kolom pelacakan sumber v2 tersedia', () {
      final db = AppDatabase();
      expect(db.transactions.origin.name, 'origin');
      expect(db.transactions.sourceCandidateId.name, 'source_candidate_id');
      expect(db.transactions.transferGroupId.name, 'transfer_group_id');
    });
  });

  group('domain entities (pure Dart)', () {
    test('TransactionItem.total = price * qty', () {
      const item = domain_tx.TransactionItem(
        name: 'Indomie',
        price: 3500,
        qty: 3,
      );
      expect(item.total, 10500);
    });

    test('Account initialBalance default 0', () {
      const acc = domain.Account(name: 'Cash', type: domain.AccountType.cash);
      expect(acc.initialBalance, 0);
    });

    test('Transaction items default kosong', () {
      final tx = domain_tx.Transaction(
        type: domain_tx.TransactionType.expense,
        amount: 50000,
        accountId: 1,
        date: DateTime(2026, 10, 15),
        createdAt: DateTime(2026, 10, 15),
      );
      expect(tx.items, isEmpty);
    });
  });
}
