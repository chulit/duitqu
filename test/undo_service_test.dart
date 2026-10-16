import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/data/repositories/drift_transaction_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/domain/entities/transaction.dart';
import 'package:duitqu/src/domain/repositories/transaction_repository.dart';
import 'package:duitqu/src/domain/services/undo_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late schema.AppDatabase db;
  late DriftTransactionRepository txRepo;
  late UndoService undo;
  late int bcaId;

  setUp(() async {
    db = schema.AppDatabase(NativeDatabase.memory());
    txRepo = DriftTransactionRepository(db);
    undo = UndoService(txRepo);
    bcaId = await DriftAccountRepository(db).save(
        const Account(name: 'BCA', type: AccountType.bank));
    await DriftCategoryRepository(db).seedDefaults();
  });

  tearDown(() => db.close());

  test('undoLast menghapus transaksi terakhir', () async {
    final id = await txRepo.save(Transaction(
      type: TransactionType.expense,
      amount: 35000,
      accountId: bcaId,
      merchant: 'Kopi Kenangan',
      date: DateTime(2026, 10, 16),
      createdAt: DateTime(2026, 10, 16),
    ));
    final tx = (await txRepo.list(const TransactionQuery()))
        .singleWhere((t) => t.id == id);
    undo.recordAutoSave(tx);

    expect(undo.lastUndoable, isNotNull);
    final label = await undo.undoLast();
    expect(label, 'Kopi Kenangan');

    final remaining = await txRepo.list(const TransactionQuery());
    expect(remaining, isEmpty);
    expect(undo.lastUndoable, isNull);
  });

  test('undo kosong → null', () async {
    expect(await undo.undoLast(), isNull);
  });
}
