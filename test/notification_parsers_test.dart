import 'package:duitqu/src/data/notification_bridge.dart';
import 'package:duitqu/src/domain/services/notification_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

RawNotification _notif({
  String package = 'com.gojek.gopay',
  String title = '',
  String text = '',
}) {
  return RawNotification(
    packageName: package,
    title: title,
    text: text,
    postedAt: DateTime(2026, 10, 16, 10, 5),
    id: 'n1',
  );
}

void main() {
  final registry = NotificationParserRegistry();

  group('GoPay', () {
    test('"Pembayaran Rp28.000 di Kopi Kenangan berhasil"', () {
      final p = registry.parse(_notif(
        text: 'Pembayaran Rp28.000 di Kopi Kenangan berhasil',
      ));
      expect(p, isNotNull);
      expect(p!.transactionType, 'expense');
      expect(p.amount, 28000);
      expect(p.merchant, 'Kopi Kenangan');
      expect(p.confidence, greaterThanOrEqualTo(0.8));
    });

    test('gagal → failed', () {
      final p = registry.parse(_notif(
        text: 'Pembayaran Rp50.000 gagal, saldo tidak cukup',
      ));
      expect(p!.transactionType, 'failed');
    });

    test('tanpa nominal → null', () {
      expect(
        registry.parse(_notif(text: 'Promo cashback 50%!')),
        isNull,
      );
    });
  });

  group('BCA', () {
    test('transfer terdeteksi', () {
      final p = registry.parse(_notif(
        package: 'com.bca',
        text: 'Transfer Rp500.000 ke BCA 1234567890 berhasil',
      ));
      expect(p, isNotNull);
      expect(p!.transactionType, 'transfer');
      expect(p.amount, 500000);
    });
  });

  group('generik', () {
    test('aplikasi tak dikenal → fallback generik', () {
      final p = registry.parse(_notif(
        package: 'com.contoh.bank',
        title: 'Info Transaksi',
        text: 'Pembayaran Rp100.000 berhasil',
      ));
      expect(p, isNotNull);
      expect(p!.amount, 100000);
      expect(p.confidence, lessThan(0.7)); // rendah → inbox
    });

    test('pending terdeteksi', () {
      final p = registry.parse(_notif(
        package: 'com.contoh.bank',
        text: 'Transaksi Rp75.000 sedang diproses',
      ));
      expect(p!.transactionType, 'pending');
    });
  });
}
