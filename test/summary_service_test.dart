import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/services/summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  TransactionType type = TransactionType.expense,
  int amount = 10000,
  int? categoryId = 1,
  int accountId = 1,
  int? toAccountId,
  String? note,
  String? merchant,
  List<TransactionItem> items = const [],
  DateTime? date,
}) =>
    Transaction(
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      note: note,
      merchant: merchant,
      date: date ?? DateTime(2026, 10, 15),
      createdAt: DateTime(2026, 10, 15),
      items: items,
    );

void main() {
  const service = SummaryService();

  group('summarize', () {
    test('kosong -> nol semua', () {
      const s = Summary();
      expect(s.income, 0);
      expect(s.expense, 0);
      expect(s.net, 0);
      expect(s.count, 0);
      expect(service.summarize(const []), isA<Summary>());
    });

    test('income - expense = net', () {
      final s = service.summarize([
        _tx(type: TransactionType.income, amount: 5000000),
        _tx(amount: 1500000),
        _tx(amount: 500000),
      ]);
      expect(s.income, 5000000);
      expect(s.expense, 2000000);
      expect(s.net, 3000000);
      expect(s.count, 3);
    });

    test('transfer dikecualikan dari pemasukan & pengeluaran', () {
      final s = service.summarize([
        _tx(type: TransactionType.transfer, amount: 1000000, toAccountId: 2),
        _tx(amount: 200000),
      ]);
      expect(s.income, 0);
      expect(s.expense, 200000);
      expect(s.net, -200000);
      expect(s.count, 1); // transfer tidak dihitung
    });
  });

  group('expenseByCategory', () {
    test('agregat per kategori, hanya expense', () {
      final m = service.expenseByCategory([
        _tx(amount: 10000, categoryId: 1),
        _tx(amount: 20000, categoryId: 1),
        _tx(amount: 50000, categoryId: 2),
        _tx(type: TransactionType.income, amount: 999999, categoryId: 1),
        _tx(type: TransactionType.transfer, amount: 999999, categoryId: 1,
            toAccountId: 2),
      ]);
      expect(m, {1: 30000, 2: 50000});
    });
  });

  group('inRange', () {
    test('inklusif batas tanggal', () {
      final txs = [
        _tx(date: DateTime(2026, 10, 1)),
        _tx(date: DateTime(2026, 10, 15)),
        _tx(date: DateTime(2026, 10, 31)),
        _tx(date: DateTime(2026, 11, 1)),
      ];
      final got =
          service.inRange(txs, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(got, hasLength(3));
    });
  });

  group('search', () {
    test('cocok catatan, merchant, nama item; case-insensitive', () {
      final txs = [
        _tx(note: 'Bayar Parkir'),
        _tx(merchant: 'Indomaret A'),
        _tx(items: const [
          TransactionItem(name: 'Indomie Goreng', price: 3500, qty: 1)
        ]),
        _tx(note: 'tidak cocok'),
      ];
      expect(service.search(txs, 'parkir'), hasLength(1));
      expect(service.search(txs, 'INDOMARET'), hasLength(1));
      expect(service.search(txs, 'indomie'), hasLength(1));
      expect(service.search(txs, 'zzz'), isEmpty);
      expect(service.search(txs, ''), hasLength(4));
    });
  });
}
