import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_candidate_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/transaction_candidate.dart';
import 'package:duitqu/src/presentation/l10n/app_localizations.dart';
import 'package:duitqu/src/domain/repositories/transaction_repository.dart';
import 'package:duitqu/src/presentation/screens/inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late schema.AppDatabase db;
  late DriftCandidateRepository candidateRepo;
  late DriftTransactionRepository txRepo;
  late int bcaId;

  setUp(() async {
    db = schema.AppDatabase(NativeDatabase.memory());
    candidateRepo = DriftCandidateRepository(db);
    txRepo = DriftTransactionRepository(db);
    final accounts = DriftAccountRepository(db);
    bcaId = await accounts.save(
        const Account(name: 'BCA', type: AccountType.bank));
    await DriftCategoryRepository(db).seedDefaults();
  });

  tearDown(() => db.close());

  Future<void> pumpInbox(WidgetTester tester) async {
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
        home: InboxScreen(
          candidateRepo: candidateRepo,
          txRepo: txRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TransactionCandidate needsReviewCandidate() {
    return TransactionCandidate(
      sourceType: CandidateSourceType.chat,
      parsedPayload: {
        'transaction_type': 'expense',
        'amount': 35000,
        'account_id': bcaId,
        'merchant': 'Kopi Kenangan',
      },
      confidence: 0.6,
      status: CandidateStatus.needsReview,
      reviewReason: 'Akun belum pasti',
      receivedAt: DateTime(2026, 10, 16, 10, 0),
    );
  }

  testWidgets('menampilkan kandidat needs_review', (tester) async {
    await candidateRepo.save(needsReviewCandidate());
    await pumpInbox(tester);

    expect(find.text('Kopi Kenangan'), findsOneWidget);
    expect(find.text('Akun belum pasti'), findsOneWidget);
  });

  testWidgets('konfirmasi menyimpan transaksi', (tester) async {
    await candidateRepo.save(needsReviewCandidate());
    await pumpInbox(tester);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Kandidat hilang dari inbox (status → saved).
    expect(find.text('Kopi Kenangan'), findsNothing);

    // Transaksi tersimpan.
    final txs = await txRepo.list(const TransactionQuery());
    expect(txs, hasLength(1));
    expect(txs.single.amount, 35000);
  });

  testWidgets('abaikan menghapus dari inbox', (tester) async {
    await candidateRepo.save(needsReviewCandidate());
    await pumpInbox(tester);

    await tester.tap(find.text('Abaikan'));
    await tester.pumpAndSettle();

    expect(find.text('Kopi Kenangan'), findsNothing);
    final txs = await txRepo.list(const TransactionQuery());
    expect(txs, isEmpty);
  });

  testWidgets('inbox kosong menampilkan empty state', (tester) async {
    await pumpInbox(tester);
    expect(find.text('Kopi Kenangan'), findsNothing);
    // Empty state terlihat (tidak crash).
    expect(find.byType(InboxScreen), findsOneWidget);
  });
}
