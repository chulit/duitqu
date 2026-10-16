import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/notification_bridge.dart';
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_candidate_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/repositories/transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/entities/transaction_candidate.dart';
import 'package:duitqu/src/domain/services/auto_record_policy.dart';
import 'package:duitqu/src/domain/services/notification_pipeline.dart';
import 'package:duitqu/src/domain/services/undo_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Financial correctness v2 (tiket 12, spec v2 §12):
/// transfer/refund/pending/undo konsisten — tidak ada transaksi ganda,
/// tidak ada transaksi dari status yang seharusnya diabaikan.
void main() {
  late schema.AppDatabase db;
  late DriftTransactionRepository txRepo;
  late DriftCandidateRepository candidateRepo;
  late NotificationPipeline pipeline;

  RawNotification notif(String package, String text, {String id = 'n1'}) {
    return RawNotification(
      packageName: package,
      title: '',
      text: text,
      postedAt: DateTime(2026, 10, 16, 10, 5),
      id: id,
    );
  }

  setUp(() async {
    db = schema.AppDatabase(NativeDatabase.memory());
    txRepo = DriftTransactionRepository(db);
    candidateRepo = DriftCandidateRepository(db);
    pipeline = NotificationPipeline(candidateRepo);
    await DriftAccountRepository(db).save(
      const Account(name: 'BCA', type: AccountType.bank),
    );
  });

  tearDown(() => db.close());

  test('transfer tidak tercatat sebagai expense ganda', () async {
    final c = await pipeline.process(
      notif('com.bca',
          'Transfer Rp500.000 ke BCA 1234567890 berhasil'),
      const AutoRecordSettings(),
    );
    expect(c, isNotNull);
    // Tipe transfer terdeteksi, bukan expense.
    expect(c!.parsedPayload['transaction_type'], 'transfer');
    // Kandidat belum jadi transaksi (tidak auto-save tanpa policy allow).
    final txs = await txRepo.list(const TransactionQuery());
    expect(txs, isEmpty);
  });

  test('refund tidak tercatat sebagai income baru', () async {
    final c = await pipeline.process(
      notif('com.gojek.gopay',
          'Refund Rp28.000 dana kembali ke GoPay'),
      const AutoRecordSettings(),
    );
    expect(c, isNotNull);
    expect(c!.parsedPayload['transactionType'],
        anyOf('refund', isNot('income')));
    final txs = await txRepo.list(const TransactionQuery());
    expect(txs, isEmpty);
  });

  test('pending tidak tercatat sampai final', () async {
    final c = await pipeline.process(
      notif('com.contoh.bank',
          'Transaksi Rp75.000 sedang diproses'),
      const AutoRecordSettings(),
    );
    expect(c, isNotNull);
    expect(c!.parsedPayload['transaction_type'], 'pending');
    // Policy harus ignore (non-final keyword).
    expect(c.status,
        anyOf(CandidateStatus.ignored, CandidateStatus.needsReview));
    final txs = await txRepo.list(const TransactionQuery());
    expect(txs, isEmpty);
  });

  test('undo membatalkan auto-save', () async {
    final undo = UndoService(txRepo);
    final tx = Transaction(
      type: TransactionType.expense,
      amount: 35000,
      accountId: 1,
      merchant: 'Kopi Kenangan',
      date: DateTime(2026, 10, 16),
      createdAt: DateTime(2026, 10, 16),
      origin: TransactionOrigin.androidNotification,
    );
    final id = await txRepo.save(tx);
    undo.recordAutoSave(Transaction(
      id: id,
      type: tx.type,
      amount: tx.amount,
      accountId: tx.accountId,
      merchant: tx.merchant,
      date: tx.date,
      createdAt: tx.createdAt,
      origin: tx.origin,
    ));

    // Batalkan.
    await undo.undoLast();
    final txs = await txRepo.list(const TransactionQuery());
    expect(txs, isEmpty);
  });

  test('failed tidak tercatat', () async {
    final c = await pipeline.process(
      notif('com.gojek.gopay',
          'Pembayaran Rp50.000 gagal, saldo tidak cukup'),
      const AutoRecordSettings(),
    );
    expect(c, isNotNull);
    expect(c!.parsedPayload['transaction_type'], 'failed');
    expect(c.status,
        anyOf(CandidateStatus.ignored, CandidateStatus.needsReview));
    final txs = await txRepo.list(const TransactionQuery());
    expect(txs, isEmpty);
  });
}
