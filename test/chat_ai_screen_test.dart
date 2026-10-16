import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/presentation/chat/chat_controller.dart';
import 'package:duitqu/src/presentation/l10n/app_localizations.dart';
import 'package:duitqu/src/presentation/screens/chat_ai_screen.dart';
import 'package:duitqu/src/presentation/user_name_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late schema.AppDatabase db;
  late DriftTransactionRepository txRepo;
  late DriftCategoryRepository categoryRepo;
  late int bcaId;
  late int makanId;

  setUp(() async {
    db = schema.AppDatabase(NativeDatabase.memory());
    txRepo = DriftTransactionRepository(db);
    categoryRepo = DriftCategoryRepository(db);
    bcaId = await DriftAccountRepository(db)
        .save(const Account(name: 'BCA', type: AccountType.bank));
    await categoryRepo.seedDefaults();
    makanId = (await categoryRepo.defaults())
        .singleWhere((c) => c.name == 'Makan & Minum')
        .id!;
  });

  tearDown(() => db.close());

  Future<void> seedMonth() async {
    final now = DateTime.now();
    await txRepo.save(Transaction(
      type: TransactionType.expense,
      amount: 35000,
      categoryId: makanId,
      accountId: bcaId,
      merchant: 'Kopi Kenangan',
      date: now,
      createdAt: now,
    ));
    await txRepo.save(Transaction(
      type: TransactionType.expense,
      amount: 50000,
      categoryId: makanId,
      accountId: bcaId,
      merchant: 'Warung Padang',
      date: now,
      createdAt: now,
    ));
    await txRepo.save(Transaction(
      type: TransactionType.income,
      amount: 5000000,
      accountId: bcaId,
      merchant: 'Gaji',
      date: now,
      createdAt: now,
    ));
  }

  ChatAssistantController makeController({void Function(QuickParse)? onSave}) {
    final c = ChatAssistantController(
      onSave: onSave ?? (_) {},
      txRepo: txRepo,
      categoryRepo: categoryRepo,
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> pumpPage(
    WidgetTester tester,
    ChatAssistantController controller,
  ) async {
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
        home: ChatAiScreen(
          controller: controller,
          nameStore: UserNameStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('header + sapaan + 4 chip aksi tampil di awal', (tester) async {
    await pumpPage(tester, makeController());

    expect(find.text('DuitQu AI'), findsOneWidget);
    expect(find.text('Siap membantu'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Hai! \u{1F44B}'), findsOneWidget);
    expect(find.textContaining('cek kondisi keuanganmu'), findsOneWidget);
    expect(find.textContaining('Catat pengeluaran'), findsOneWidget);
    expect(find.textContaining('Catat pemasukan'), findsOneWidget);
    expect(find.textContaining('Laporan bulan ini'), findsOneWidget);
    expect(find.textContaining('Pengeluaran terbesar'), findsOneWidget);
    expect(find.text('Tulis pesan atau transaksi...'), findsOneWidget);
  });

  testWidgets('chip "Laporan bulan ini" menjawab dari data asli', (tester) async {
    await seedMonth();
    await pumpPage(tester, makeController());

    await tester.tap(find.textContaining('Laporan bulan ini'));
    await tester.pumpAndSettle();

    // Bubble user + jawaban asisten dari data seed.
    expect(find.textContaining('Laporan bulan ini'), findsWidgets);
    expect(find.textContaining('Pemasukan: Rp 5.000.000'), findsOneWidget);
    expect(find.textContaining('Pengeluaran: Rp 85.000'), findsOneWidget);
    // Chip aksi hilang setelah ada pesan user.
    expect(find.textContaining('Catat pengeluaran'), findsNothing);
  });

  testWidgets('chip "Pengeluaran terbesar" menyebut kategori teratas',
      (tester) async {
    await seedMonth();
    await pumpPage(tester, makeController());

    await tester.tap(find.textContaining('Pengeluaran terbesar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Makan & Minum'), findsOneWidget);
    expect(find.textContaining('Rp 85.000'), findsOneWidget);
  });

  testWidgets('riwayat dari sheet dilanjutkan di halaman penuh', (tester) async {
    final controller = makeController();
    await controller.submit(
      'beli kopi 28 ribu',
      t: const AppLocalizations(Locale('id')),
    );

    await pumpPage(tester, controller);

    // Bubble user + kartu konfirmasi langsung tampil.
    expect(find.text('beli kopi 28 ribu'), findsOneWidget);
    expect(find.textContaining('Rp 28.000'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('bubble user tampil jam + centang ganda', (tester) async {
    final controller = makeController();
    await controller.submit(
      'halo apa kabar',
      t: const AppLocalizations(Locale('id')),
    );

    await pumpPage(tester, controller);

    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
  });

  testWidgets('kartu konfirmasi: Simpan memanggil onSave', (tester) async {
    QuickParse? saved;
    final controller = makeController(onSave: (p) => saved = p);
    await controller.submit(
      'makan siang 35 ribu pakai GoPay',
      t: const AppLocalizations(Locale('id')),
    );

    await pumpPage(tester, controller);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.amount, 35000);
    // Nominal pengeluaran berwarna merah dengan tanda minus.
    expect(find.textContaining('Rp 35.000'), findsWidgets);
  });
}
