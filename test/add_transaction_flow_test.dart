import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/presentation/quick_add_defaults.dart';
import 'package:duitqu/src/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('alur catat kilat: tambah pengeluaran muncul di riwayat',
      (tester) async {
    final db = schema.AppDatabase(NativeDatabase.memory());
    final accountRepo = DriftAccountRepository(db);
    final categoryRepo = DriftCategoryRepository(db);
    final txRepo = DriftTransactionRepository(db);
    await categoryRepo.seedDefaults();
    await accountRepo.save(
        const Account(name: 'Cash', type: AccountType.cash));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          txRepo: txRepo,
          accountRepo: accountRepo,
          categoryRepo: categoryRepo,
          defaults: QuickAddDefaults(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kondisi awal: riwayat kosong.
    expect(find.textContaining('Belum ada transaksi'), findsOneWidget);

    // Buka sheet catat kilat.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Catat transaksi'), findsOneWidget);

    // Isi nominal.
    await tester.enterText(find.byKey(const Key('amountField')), '75000');
    // Pilih kategori (sudah default yang pertama, tap untuk memastikan).
    await tester.tap(find.text('Makan & Minum'));
    await tester.pumpAndSettle();

    // Scroll tombol simpan ke layar lalu simpan.
    await tester.ensureVisible(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    // Muncul di riwayat dengan format Rupiah.
    expect(find.textContaining('Rp 75.000'), findsOneWidget);
    expect(find.textContaining('Belum ada transaksi'), findsNothing);

    await db.close();
  });

  testWidgets('hapus transaksi minta konfirmasi dulu', (tester) async {
    final db = schema.AppDatabase(NativeDatabase.memory());
    final accountRepo = DriftAccountRepository(db);
    final categoryRepo = DriftCategoryRepository(db);
    final txRepo = DriftTransactionRepository(db);
    await categoryRepo.seedDefaults();
    await accountRepo.save(
        const Account(name: 'Cash', type: AccountType.cash));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          txRepo: txRepo,
          accountRepo: accountRepo,
          categoryRepo: categoryRepo,
          defaults: QuickAddDefaults(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountField')), '25000');
    await tester.ensureVisible(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    expect(find.text('−Rp 25.000'), findsOneWidget);

    // Ketuk ikon hapus -> dialog konfirmasi muncul, belum terhapus.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Hapus transaksi?'), findsOneWidget);

    // Batal -> tetap ada.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('−Rp 25.000'), findsOneWidget);

    // Hapus -> hilang, kembali ke empty state.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('−Rp 25.000'), findsNothing);
    expect(find.textContaining('Belum ada transaksi'), findsOneWidget);

    await db.close();
  });
}
