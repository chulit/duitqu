import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/services/chat_correction_service.dart';
import 'package:duitqu/src/domain/services/transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

int? _amount(String text) =>
    TransactionParser().parseChat(text).amount;

Transaction _tx({
  int? id,
  String? merchant,
  int amount = 25000,
  String? note,
}) {
  return Transaction(
    id: id,
    type: TransactionType.expense,
    amount: amount,
    accountId: 1,
    merchant: merchant,
    note: note,
    date: DateTime(2026, 10, 16, 10, 0),
    createdAt: DateTime(2026, 10, 16, 10, 0),
  );
}

void main() {
  final service = ChatCorrectionService();

  group('interpretasi perintah', () {
    test('"kopi tadi ternyata 28 ribu" → koreksi', () {
      final cmd = service.interpret(
        'kopi tadi ternyata 28 ribu, bukan 25 ribu',
        _amount,
      );
      expect(cmd, isNotNull);
      expect(cmd!.action, CorrectionAction.correct);
      expect(cmd.newAmount, 28000);
      expect(cmd.merchantHint, contains('kopi'));
    });

    test('"hapus makan siang tadi" → hapus', () {
      final cmd = service.interpret(
        'hapus catatan makan siang yang tadi',
        _amount,
      );
      expect(cmd, isNotNull);
      expect(cmd!.action, CorrectionAction.delete);
      expect(cmd.newAmount, isNull);
      expect(cmd.merchantHint, contains('makan'));
    });

    test('bukan perintah → null', () {
      expect(service.interpret('makan siang 35 ribu', _amount), isNull);
      expect(service.interpret('', _amount), isNull);
    });
  });

  group('resolusi konteks', () {
    final recent = [
      _tx(id: 3, merchant: 'Kopi Kenangan', amount: 25000),
      _tx(id: 2, merchant: 'Indomaret', amount: 50000),
      _tx(id: 1, merchant: 'Kopi Tuku', amount: 20000),
    ];

    test('"kopi" → transaksi kopi terbaru', () {
      final cmd = service.interpret('kopi ternyata 28 ribu', _amount)!;
      final target = service.resolveTarget(cmd, recent);
      expect(target?.id, 3);
    });

    test('tanpa hint → transaksi terakhir', () {
      final cmd = service.interpret('ternyata 28 ribu', _amount)!;
      // "ternyata 28 ribu" tanpa merchant → hint null → ambil terakhir.
      final target = service.resolveTarget(cmd, recent);
      expect(target?.id, 3);
    });

    test('tidak cocok → null', () {
      final cmd = service.interpret(
        'hapus tiket pesawat tadi',
        _amount,
      )!;
      expect(service.resolveTarget(cmd, recent), isNull);
    });

    test('list kosong → null', () {
      final cmd = service.interpret('kopi ternyata 28 ribu', _amount)!;
      expect(service.resolveTarget(cmd, []), isNull);
    });
  });
}
