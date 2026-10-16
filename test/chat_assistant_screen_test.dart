import 'package:duitqu/src/presentation/l10n/app_localizations.dart';
import 'package:duitqu/src/presentation/screens/chat_assistant_screen.dart';
import 'package:duitqu/src/presentation/widgets/chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpChat(
    WidgetTester tester, {
    void Function(QuickParse parsed)? onSave,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: ChatAssistantScreen(
          onSave: onSave ?? (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sapaan awal tampil', (tester) async {
    await pumpChat(tester);
    expect(find.textContaining('Ada transaksi baru'), findsOneWidget);
    expect(find.text('DuitQu Assistant'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('input "makan siang 35 ribu" memunculkan kartu konfirmasi',
      (tester) async {
    await pumpChat(tester);
    await tester.enterText(
        find.byType(TextField), 'makan siang 35 ribu pakai GoPay');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Bubble user + hasil parse dari data ASLI.
    expect(find.text('makan siang 35 ribu pakai GoPay'), findsOneWidget);
    expect(find.textContaining('Ini hasilnya'), findsOneWidget);
    expect(find.text('Siang'), findsOneWidget);
    expect(find.text('Rp 35.000'), findsOneWidget);
    expect(find.text('Gopay'), findsOneWidget);
    expect(find.text('Simpan Transaksi'), findsOneWidget);
  });

  testWidgets('Simpan Transaksi memanggil onSave + bubble sukses',
      (tester) async {
    QuickParse? saved;
    await pumpChat(tester, onSave: (p) => saved = p);
    await tester.enterText(find.byType(TextField), 'makan siang 35 ribu');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.amount, 35000);
    expect(saved!.description, 'Siang');
    expect(find.text('Sudah tersimpan!'), findsOneWidget);
    expect(find.textContaining('Mau catat yang lain'), findsOneWidget);
  });

  testWidgets('teks tanpa nominal dijawab dengan ramah', (tester) async {
    await pumpChat(tester);
    await tester.enterText(find.byType(TextField), 'halo apa kabar');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('belum paham'), findsOneWidget);
    expect(find.text('Simpan Transaksi'), findsNothing);
  });
}
