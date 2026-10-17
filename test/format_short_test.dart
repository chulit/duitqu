import 'package:duitqu/src/presentation/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatRupiahShort', () {
    test('jutaan dengan 2 desimal', () {
      expect(formatRupiahShort(4350000), 'Rp 4,35 jt');
    });
    test('jutaan bulat tanpa desimal', () {
      expect(formatRupiahShort(5000000), 'Rp 5 jt');
    });
    test('ratusan ribu', () {
      expect(formatRupiahShort(783000), 'Rp 783 rb');
    });
    test('ribuan dengan desimal', () {
      expect(formatRupiahShort(1500), 'Rp 1,5 rb');
    });
    test('di bawah seribu pakai format penuh', () {
      expect(formatRupiahShort(500), 'Rp 500');
    });
  });
}
