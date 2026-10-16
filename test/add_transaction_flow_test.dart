import 'package:drift/native.dart';
import 'package:duitqu/src/data/backup_service.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_candidate_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/services/transfer_service.dart';
import 'package:duitqu/src/presentation/l10n/app_localizations.dart';
import 'package:duitqu/src/presentation/quick_add_defaults.dart';
import 'package:duitqu/src/presentation/theme_mode_store.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:duitqu/src/presentation/screens/add_transaction_sheet.dart';
import 'package:duitqu/src/presentation/screens/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pompa AppShell dengan database in-memory.
Future<Harness> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final db = schema.AppDatabase(NativeDatabase.memory());
  final accountRepo = DriftAccountRepository(db);
  final categoryRepo = DriftCategoryRepository(db);
  final txRepo = DriftTransactionRepository(db);
  final transferService = TransferService(txRepo, categoryRepo);
  await categoryRepo.seedDefaults();
  await accountRepo.save(const Account(name: 'Cash', type: AccountType.cash));

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
      home: AppShell(
        txRepo: txRepo,
        accountRepo: accountRepo,
        categoryRepo: categoryRepo,
        candidateRepo: DriftCandidateRepository(db),
        transferService: transferService,
        defaults: QuickAddDefaults(),
        backup: BackupService(db),
        themeStore: ThemeModeStore(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return Harness(
    db: db,
    accountRepo: accountRepo,
    categoryRepo: categoryRepo,
    txRepo: txRepo,
    transferService: transferService,
  );
}

class Harness {
  final schema.AppDatabase db;
  final DriftAccountRepository accountRepo;
  final DriftCategoryRepository categoryRepo;
  final DriftTransactionRepository txRepo;
  final TransferService transferService;

  Harness({
    required this.db,
    required this.accountRepo,
    required this.categoryRepo,
    required this.txRepo,
    required this.transferService,
  });
}

/// Buka sheet tambah langsung (tanpa lewat chat). Tidak di-await
/// agar test bisa berinteraksi dengan sheet yang terbuka.
void openSheet(
  WidgetTester tester,
  Harness h, {
  int? initialAmount,
  String? initialNote,
}) {
  final ctx = tester.element(find.byType(AppShell));
  // ignore: unawaited_futures
  showModalBottomSheet<bool>(
    context: ctx,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddTransactionSheet(
      txRepo: h.txRepo,
      accountRepo: h.accountRepo,
      categoryRepo: h.categoryRepo,
      transferService: h.transferService,
      defaults: QuickAddDefaults(),
      initialAmount: initialAmount,
      initialNote: initialNote,
    ),
  );
}

void main() {
  testWidgets('chat: ketik "bensin 50 ribu" -> hasil cepat -> simpan', (
    tester,
  ) async {
    final h = await pumpApp(tester);

    // Kondisi awal: riwayat kosong.
    expect(find.textContaining('Belum ada transaksi'), findsOneWidget);

    // Ketuk tombol chat bulat di tengah nav.
    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pumpAndSettle();

    // Ketik + kirim.
    await tester.enterText(find.byType(TextField).first, 'bensin 50 ribu');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Hasil cepat muncul dengan nominal terparse.
    expect(find.text('Rp 50.000'), findsOneWidget);

    // Simpan -> sheet tambah terbuka dengan prefill.
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Catat transaksi'), findsOneWidget);
    final amountField = tester.widget<TextField>(
      find.byKey(const Key('amountField')),
    );
    expect(amountField.controller!.text, '50000');

    // Pilih kategori + simpan.
    await tester.tap(find.text('Makan & Minum'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    // Kembali ke home dari layar chat.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Muncul di riwayat.
    expect(find.text('−Rp 50.000'), findsOneWidget);
    expect(find.textContaining('Belum ada transaksi'), findsNothing);

    await h.db.close();
  });

  testWidgets('hapus transaksi minta konfirmasi dulu', (tester) async {
    final h = await pumpApp(tester);

    // Buat satu transaksi via sheet.
    openSheet(tester, h);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountField')), '25000');
    await tester.tap(find.text('Makan & Minum'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    expect(find.text('−Rp 25.000'), findsOneWidget);

    // Ketuk baris -> sheet edit terbuka.
    await tester.tap(find.text('−Rp 25.000'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah transaksi'), findsOneWidget);

    // Hapus -> dialog konfirmasi, belum terhapus.
    await tester.ensureVisible(find.byKey(const Key('deleteButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteButton')));
    await tester.pumpAndSettle();
    expect(find.text('Hapus transaksi?'), findsOneWidget);

    // Batal -> tetap ada.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah transaksi'), findsOneWidget);

    // Hapus beneran -> hilang.
    await tester.tap(find.byKey(const Key('deleteButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    expect(find.text('−Rp 25.000'), findsNothing);

    await h.db.close();
  });

  testWidgets('catat dengan rincian item: total otomatis dari item', (
    tester,
  ) async {
    final h = await pumpApp(tester);

    openSheet(tester, h);
    await tester.pumpAndSettle();

    // Tambah 2 item.
    await tester.tap(find.byKey(const Key('addItemButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('itemName_0')), 'Indomie');
    await tester.enterText(find.byKey(const Key('itemPrice_0')), '3500');
    await tester.enterText(find.byKey(const Key('itemQty_0')), '2');

    await tester.tap(find.byKey(const Key('addItemButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('itemName_1')), 'Telur');
    await tester.enterText(find.byKey(const Key('itemPrice_1')), '2000');
    await tester.enterText(find.byKey(const Key('itemQty_1')), '3');
    await tester.pumpAndSettle();

    // Total otomatis 7000 + 6000 = 13000.
    expect(find.textContaining('Rp 13.000'), findsWidgets);

    await tester.tap(find.text('Makan & Minum'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(find.text('−Rp 13.000'), findsOneWidget);

    await h.db.close();
  });

  testWidgets('transfer dengan biaya admin: tercatat 2 transaksi', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await h.accountRepo.save(
      const Account(name: 'BCA', type: AccountType.bank),
    );

    openSheet(tester, h);
    await tester.pumpAndSettle();

    // Ganti tipe ke Transfer.
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amountField')), '100000');

    // Pilih akun tujuan (BCA) — chip akun.
    await tester.tap(find.text('BCA').last);
    await tester.pumpAndSettle();

    // Biaya admin.
    await tester.ensureVisible(find.byKey(const Key('feeField')));
    await tester.enterText(find.byKey(const Key('feeField')), '2500');

    await tester.ensureVisible(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    // Riwayat: transfer + expense Biaya Admin (judul + pil kategori).
    expect(find.text('Transfer'), findsWidgets);
    expect(find.textContaining('Biaya Admin'), findsWidgets);

    await h.db.close();
  });

  testWidgets('kartu statistik: pemasukan, pengeluaran, sisa', (tester) async {
    final h = await pumpApp(tester);
    final cats = await h.categoryRepo.defaults();
    final cashId = (await h.accountRepo.list()).first.id!;
    final makanId = cats.singleWhere((c) => c.name == 'Makan & Minum').id!;
    final gajiId = cats.singleWhere((c) => c.name == 'Gaji').id!;
    final now = DateTime.now();

    await h.txRepo.save(
      Transaction(
        type: TransactionType.income,
        amount: 5000000,
        categoryId: gajiId,
        accountId: cashId,
        date: now,
        createdAt: now,
      ),
    );
    await h.txRepo.save(
      Transaction(
        type: TransactionType.expense,
        amount: 2000000,
        categoryId: makanId,
        accountId: cashId,
        date: now,
        createdAt: now,
      ),
    );
    await tester.pumpAndSettle();

    // Kartu statistik menampilkan ketiga angka.
    expect(find.text('Rp 5.000.000'), findsOneWidget);
    expect(find.text('Rp 2.000.000'), findsOneWidget);
    expect(find.text('Rp 3.000.000'), findsOneWidget);

    await h.db.close();
  });
}
