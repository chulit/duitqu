import 'package:duitqu/src/presentation/chat/chat_controller.dart';
import 'package:duitqu/src/presentation/l10n/app_localizations.dart';
import 'package:duitqu/src/presentation/widgets/chat_assistant_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    void Function(QuickParse parsed)? onSave,
  }) async {
    final controller = ChatAssistantController(
      onSave: onSave ?? (_) {},
    );
    addTearDown(controller.dispose);
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
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ChatAssistantSheet(
              scrollController: ScrollController(),
              controller: controller,
              onExpand: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('header + chip saran tampil di awal', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Catat transaksi dengan chat'), findsOneWidget);
    expect(find.textContaining('nanti aku yang catat'), findsOneWidget);
    expect(find.text('\u2615 Beli kopi 28 ribu'), findsOneWidget);
    expect(find.text('\u{1F45B} Terima gaji 5 juta'), findsOneWidget);
    expect(find.text('Lainnya...'), findsOneWidget);
  });

  testWidgets('tap chip langsung kirim sebagai pesan', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('\u2615 Beli kopi 28 ribu'));
    await tester.pumpAndSettle();

    // Bubble user + kartu konfirmasi muncul; chip hilang.
    expect(find.text('Beli kopi 28 ribu'), findsOneWidget);
    expect(find.text('Rp 28.000'), findsOneWidget);
    expect(find.text('Simpan Transaksi'), findsOneWidget);
    expect(find.text('Lainnya...'), findsNothing);
  });

  testWidgets('input "makan siang 35 ribu" memunculkan kartu konfirmasi',
      (tester) async {
    await pumpSheet(tester);
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
    await pumpSheet(tester, onSave: (p) => saved = p);
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
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), 'halo apa kabar');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('belum paham'), findsOneWidget);
    expect(find.text('Simpan Transaksi'), findsNothing);
  });
}
