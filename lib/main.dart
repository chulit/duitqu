import 'package:flutter/material.dart';

import 'src/data/backup_service.dart';
import 'src/data/database.dart';
import 'src/data/repositories/drift_account_repository.dart';
import 'src/data/repositories/drift_category_repository.dart';
import 'src/data/repositories/drift_transaction_repository.dart';
import 'src/domain/services/transfer_service.dart';
import 'src/presentation/quick_add_defaults.dart';
import 'src/presentation/screens/home_screen.dart';
import 'src/presentation/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final accountRepo = DriftAccountRepository(db);
  final categoryRepo = DriftCategoryRepository(db);
  final txRepo = DriftTransactionRepository(db);
  final transferService = TransferService(txRepo, categoryRepo);
  final backup = BackupService(db);
  await categoryRepo.seedDefaults();

  runApp(DuitQuApp(
    txRepo: txRepo,
    accountRepo: accountRepo,
    categoryRepo: categoryRepo,
    transferService: transferService,
    backup: backup,
  ));
}

class DuitQuApp extends StatelessWidget {
  final DriftTransactionRepository txRepo;
  final DriftAccountRepository accountRepo;
  final DriftCategoryRepository categoryRepo;
  final TransferService transferService;
  final BackupService backup;

  const DuitQuApp({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.transferService,
    required this.backup,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuitQu',
      theme: DuitQuTheme.light(),
      darkTheme: DuitQuTheme.dark(),
      home: HomeScreen(
        txRepo: txRepo,
        accountRepo: accountRepo,
        categoryRepo: categoryRepo,
        transferService: transferService,
        backup: backup,
        defaults: QuickAddDefaults(),
      ),
    );
  }
}
