import 'package:duitqu/src/domain/entities/transaction_candidate.dart';
import 'package:duitqu/src/domain/services/transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = TransactionParser();

  group('ekstraksi nominal Indonesia', () {
    test('"35 ribu" → 35000', () {
      expect(parser.parseChat('makan 35 ribu').amount, 35000);
    });

    test('"7 juta" → 7000000', () {
      expect(parser.parseChat('dapat gaji 7 juta').amount, 7000000);
    });

    test('"Rp28.000" → 28000', () {
      expect(parser.parseChat('bayar Rp28.000').amount, 28000);
    });

    test('"50rb" → 50000', () {
      expect(parser.parseChat('jajan 50rb').amount, 50000);
    });

    test('"25k" → 25000', () {
      expect(parser.parseChat('makan malam 25k').amount, 25000);
    });

    test('"1,5jt" → 1500000', () {
      expect(parser.parseChat('dapat 1,5jt').amount, 1500000);
    });
  });

  group('klasifikasi tipe', () {
    test('expense', () {
      expect(
        parser.parseChat('bayar listrik 150rb').transactionType,
        'expense',
      );
    });

    test('income', () {
      expect(
        parser.parseChat('dapat bonus 500rb').transactionType,
        'income',
      );
    });

    test('transfer', () {
      final p =
          parser.parseChat('transfer 500 ribu dari BCA ke GoPay');
      expect(p.transactionType, 'transfer');
      expect(p.accountName, 'bca');
      expect(p.toAccountName, 'gopay');
    });
  });

  group('kasus lengkap', () {
    test('"makan siang 35 ribu pakai GoPay"', () {
      final p = parser.parseChat('makan siang 35 ribu pakai GoPay');
      expect(p.transactionType, 'expense');
      expect(p.amount, 35000);
      expect(p.accountName, 'gopay');
      expect(p.confidence, greaterThan(0.7));
    });
  });

  group('ambigu → confidence rendah', () {
    test('teks kosong', () {
      final p = parser.parseChat('');
      expect(p.confidence, 0.0);
    });

    test('tanpa nominal → confidence rendah', () {
      final p = parser.parseChat('tadi jajan');
      expect(p.amount, isNull);
      expect(p.confidence, lessThan(0.5));
    });

    test('tanpa tipe → confidence rendah', () {
      final p = parser.parseChat('35000');
      expect(p.transactionType, isNull);
      expect(p.confidence, lessThan(0.5));
    });
  });

  group('parse() → kandidat', () {
    test('menghasilkan kandidat chat tanpa write DB', () {
      final c = parser.parse('makan 35 ribu pakai gopay');
      expect(c.sourceType, CandidateSourceType.chat);
      expect(c.parsedPayload['amount'], 35000);
      expect(c.parsedPayload['transaction_type'], 'expense');
      expect(c.status, CandidateStatus.parsing);
      expect(c.id, isNull); // belum disimpan
    });
  });
}
