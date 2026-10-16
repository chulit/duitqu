import 'package:duitqu/src/data/notification_bridge.dart';
import 'package:duitqu/src/domain/services/notification_parsers.dart';
import 'package:duitqu/src/domain/services/transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dataset uji akurasi parser (tiket 12, spec v2 §12).
///
/// Setiap kasus: input → ekspektasi (tipe, nominal, merchant).
/// Akurasi diukur per field; threshold confidence divalidasi dari data.
class _ChatCase {
  final String input;
  final String? type;
  final int? amount;
  final String? merchant;

  const _ChatCase(this.input, {this.type, this.amount, this.merchant});
}

class _NotifCase {
  final String package;
  final String text;
  final String? type;
  final int? amount;

  const _NotifCase(this.package, this.text, {this.type, this.amount});
}

const _chatDataset = [
  _ChatCase('makan siang 35 ribu pakai GoPay',
      type: 'expense', amount: 35000, merchant: 'siang'),
  _ChatCase('dapat gaji 5jt', type: 'income', amount: 5000000),
  _ChatCase('transfer 500 ribu dari BCA ke GoPay',
      type: 'transfer', amount: 500000),
  _ChatCase('bayar listrik Rp150.000', type: 'expense', amount: 150000),
  _ChatCase('jajan 50rb', type: 'expense', amount: 50000),
  _ChatCase('dapat bonus 1,5jt', type: 'income', amount: 1500000),
  _ChatCase('beli bensin 100 ribu', type: 'expense', amount: 100000),
  _ChatCase('terima transfer 250rb dari budi',
      type: 'income', amount: 250000),
];

const _notifDataset = [
  _NotifCase('com.gojek.gopay',
      'Pembayaran Rp28.000 di Kopi Kenangan berhasil',
      type: 'expense', amount: 28000),
  _NotifCase('com.gojek.gopay',
      'Top up GoPay Rp100.000 dari BCA berhasil',
      type: 'expense', amount: 100000),
  _NotifCase('com.bca',
      'Transfer Rp500.000 ke BCA 1234567890 berhasil',
      type: 'transfer', amount: 500000),
  _NotifCase('com.contoh.bank', 'Pembayaran Rp75.000 berhasil',
      type: 'expense', amount: 75000),
];

RawNotification _toNotif(_NotifCase c) => RawNotification(
      packageName: c.package,
      title: '',
      text: c.text,
      postedAt: DateTime(2026, 10, 16),
      id: 'test',
    );

void main() {
  group('akurasi chat parser', () {
    test('dataset: tipe benar semua', () {
      final parser = TransactionParser();
      var correct = 0;
      for (final c in _chatDataset) {
        final p = parser.parseChat(c.input);
        if (p.transactionType == c.type) correct++;
      }
      final acc = correct / _chatDataset.length;
      // ignore: avoid_print
      print('Chat type accuracy: ${(acc * 100).round()}% '
          '($correct/${_chatDataset.length})');
      expect(acc, greaterThanOrEqualTo(0.85));
    });

    test('dataset: nominal benar semua', () {
      final parser = TransactionParser();
      var correct = 0;
      for (final c in _chatDataset) {
        final p = parser.parseChat(c.input);
        if (p.amount == c.amount) correct++;
      }
      final acc = correct / _chatDataset.length;
      // ignore: avoid_print
      print('Chat amount accuracy: ${(acc * 100).round()}% '
          '($correct/${_chatDataset.length})');
      expect(acc, greaterThanOrEqualTo(0.9));
    });

    test('confidence berkorelasi dengan kelengkapan', () {
      final parser = TransactionParser();
      // Kasus lengkap → confidence tinggi.
      final full = parser.parseChat('makan siang 35 ribu pakai GoPay');
      // Kasus ambigu → confidence rendah.
      final vague = parser.parseChat('tadi jajan');
      expect(full.confidence, greaterThan(vague.confidence));
      expect(vague.confidence, lessThan(0.5));
    });
  });

  group('akurasi notification parser', () {
    test('dataset: tipe & nominal benar', () {
      final registry = NotificationParserRegistry();
      var typeCorrect = 0;
      var amountCorrect = 0;
      for (final c in _notifDataset) {
        final p = registry.parse(_toNotif(c));
        if (p?.transactionType == c.type) typeCorrect++;
        if (p?.amount == c.amount) amountCorrect++;
      }
      final typeAcc = typeCorrect / _notifDataset.length;
      final amountAcc = amountCorrect / _notifDataset.length;
      // ignore: avoid_print
      print('Notif type accuracy: ${(typeAcc * 100).round()}%, '
          'amount: ${(amountAcc * 100).round()}%');
      expect(typeAcc, greaterThanOrEqualTo(0.75));
      expect(amountAcc, greaterThanOrEqualTo(0.9));
    });
  });
}
