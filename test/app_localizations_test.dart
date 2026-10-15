import 'package:duitqu/src/data/backup_service.dart';
import 'package:duitqu/src/presentation/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = AppLocalizations(Locale('id'));
  const en = AppLocalizations(Locale('en'));

  group('string UI', () {
    test('Indonesia default', () {
      expect(id.cancel, 'Batal');
      expect(id.income, 'Masuk');
      expect(id.expense, 'Keluar');
      expect(id.save, 'Catat');
      expect(id.exportCsv, 'Ekspor CSV');
    });

    test('Inggris', () {
      expect(en.cancel, 'Cancel');
      expect(en.income, 'Income');
      expect(en.expense, 'Expense');
      expect(en.save, 'Save');
      expect(en.exportCsv, 'Export CSV');
    });

    test('nama aplikasi tidak diterjemahkan', () {
      expect(id.appTitle, 'DuitQu');
      expect(en.appTitle, 'DuitQu');
    });
  });

  group('bulan', () {
    test('Indonesia', () {
      expect(id.shortMonth(10), 'Okt');
      expect(id.longMonth(10), 'Oktober');
    });

    test('Inggris', () {
      expect(en.shortMonth(10), 'Oct');
      expect(en.longMonth(10), 'October');
    });
  });

  group('alasan impor', () {
    test('kode dikenal -> lokal', () {
      expect(id.skippedReason('amountNotPositive', []), 'amount harus > 0');
      expect(en.skippedReason('amountNotPositive', []), 'amount must be > 0');
      expect(
        id.skippedReason('accountMissing', ['7']),
        'akun 7 tidak ada di file backup',
      );
      expect(
        en.skippedReason('notANumber', ['amount', 'x']),
        'column amount is not a number: "x"',
      );
    });

    test('format exception', () {
      expect(id.backupFormatMessage('badTag'), contains('DuitQu'));
      expect(en.backupFormatMessage('badTag'), contains('DuitQu'));
    });

    test('SkippedRow membawa kode + argumen', () {
      const s = SkippedRow(
          row: 3, reason: 'x', code: 'qtyNotPositive', args: []);
      expect(id.localizedSkippedReason(s), 'qty harus > 0');
      expect(en.localizedSkippedReason(s), 'qty must be > 0');
    });
  });

  group('delegate', () {
    test('didukung id + en', () {
      expect(AppLocalizations.supportedLocales,
          [const Locale('id'), const Locale('en')]);
      expect(AppLocalizations.delegate.isSupported(const Locale('id')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      expect(
          AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
    });
  });
}
