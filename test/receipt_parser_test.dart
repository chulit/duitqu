import 'package:duitqu/src/domain/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = ReceiptParser();

  group('ReceiptParser', () {
    test('struk lengkap: merchant + total + tanggal', () {
      const ocr = '''
KOPI KENANGAN
Jl. Sudirman No. 88 Jakarta
Telp: 021-5551234

Kopi Susu Besar      1   Rp 28.000
Roti Bakar          1   Rp 15.000
--------------------------------
TOTAL                     Rp 43.000
Tunai                   Rp 50.000
Kembali                  Rp 7.000

12/10/2026  14:35
Terima kasih!
''';
      final p = parser.parse(ocr);
      expect(p, isNotNull);
      expect(p!.amount, 43000);
      expect(p.merchant, 'KOPI KENANGAN');
      expect(p.date, DateTime(2026, 10, 12));
      expect(p.confidence, greaterThanOrEqualTo(0.9));
    });

    test('grand total di tengah struk', () {
      const ocr = '''
INDOMARET TAMAN MINI
Struk Belanja

Indomie Goreng 5x        17.500
Aqua 600ml 2x            10.000
Grand Total               27.500
Debit BCA               27.500

01-09-2026
''';
      final p = parser.parse(ocr);
      expect(p, isNotNull);
      expect(p!.amount, 27500);
      expect(p.merchant, contains('INDOMARET'));
      expect(p.date, DateTime(2026, 9, 1));
    });

    test('tanpa total yang meyakinkan → null', () {
      const ocr = '''
PROMO HARI INI
Diskon 50% semua kopi
Syarat dan ketentuan berlaku
''';
      expect(parser.parse(ocr), isNull);
    });

    test('teks kosong → null', () {
      expect(parser.parse(''), isNull);
      expect(parser.parse('   \n  '), isNull);
    });

    test('buram: hanya nominal terbaca → confidence rendah', () {
      const ocr = '''
... ... ...
Rp 125.000
... ...
''';
      final p = parser.parse(ocr);
      expect(p, isNotNull);
      expect(p!.amount, 125000);
      expect(p.merchant, isNull);
      expect(p.date, isNull);
      // Hanya nominal → confidence rendah → masuk inbox, bukan auto-save.
      expect(p.confidence, lessThan(0.8));
    });

    test('tanggal format titik dd.mm.yyyy', () {
      const ocr = '''
TOKO BERKAH JAYA
Beras 5kg        Rp 68.000
TOTAL            Rp 68.000
05.10.2026
''';
      final p = parser.parse(ocr);
      expect(p, isNotNull);
      expect(p!.amount, 68000);
      expect(p.date, DateTime(2026, 10, 5));
    });

    test('total tanpa kata "total" → fallback nominal terbesar', () {
      const ocr = '''
WARUNG PADANG SEDERHANA
Nasi + Ayam      25.000
Es Teh            5.000
Bayar           30.000
''';
      final p = parser.parse(ocr);
      expect(p, isNotNull);
      // "Bayar 30.000" bukan keyword total; fallback ambil terbesar.
      expect(p!.amount, 30000);
    });
  });
}
