import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/data/backup_service.dart';
import 'src/data/database.dart';
import 'src/data/repositories/drift_account_repository.dart';
import 'src/data/repositories/drift_candidate_repository.dart';
import 'src/data/repositories/drift_category_repository.dart';
import 'src/data/repositories/drift_transaction_repository.dart';
import 'src/domain/services/transfer_service.dart';
import 'src/presentation/l10n/app_localizations.dart';
import 'src/presentation/locale_store.dart';
import 'src/presentation/quick_add_defaults.dart';
import 'src/presentation/screens/app_shell.dart';
import 'src/presentation/theme.dart';
import 'src/presentation/theme_mode_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final accountRepo = DriftAccountRepository(db);
  final categoryRepo = DriftCategoryRepository(db);
  final txRepo = DriftTransactionRepository(db);
  final candidateRepo = DriftCandidateRepository(db);
  final transferService = TransferService(txRepo, categoryRepo);
  final backup = BackupService(db);
  await categoryRepo.seedDefaults();

  runApp(
    DuitQuApp(
      txRepo: txRepo,
      accountRepo: accountRepo,
      categoryRepo: categoryRepo,
      candidateRepo: candidateRepo,
      transferService: transferService,
      backup: backup,
      themeStore: ThemeModeStore(),
      localeStore: LocaleStore(),
    ),
  );
}

class DuitQuApp extends StatefulWidget {
  final DriftTransactionRepository txRepo;
  final DriftAccountRepository accountRepo;
  final DriftCategoryRepository categoryRepo;
  final DriftCandidateRepository candidateRepo;
  final TransferService transferService;
  final BackupService backup;
  final ThemeModeStore themeStore;
  final LocaleStore localeStore;

  const DuitQuApp({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.candidateRepo,
    required this.transferService,
    required this.backup,
    required this.themeStore,
    required this.localeStore,
  });

  @override
  State<DuitQuApp> createState() => _DuitQuAppState();
}

class _DuitQuAppState extends State<DuitQuApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeStore,
      builder: (context, mode, _) => ValueListenableBuilder<Locale?>(
        valueListenable: widget.localeStore,
        builder: (context, locale, _) => MaterialApp(
        title: 'DuitQu',
        theme: DuitQuTheme.light(),
        darkTheme: DuitQuTheme.dark(),
        themeMode: mode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
        home: AppShell(
          txRepo: widget.txRepo,
          accountRepo: widget.accountRepo,
          categoryRepo: widget.categoryRepo,
          candidateRepo: widget.candidateRepo,
          transferService: widget.transferService,
          backup: widget.backup,
          defaults: QuickAddDefaults(),
          themeStore: widget.themeStore,
          localeStore: widget.localeStore,
        ),
      ),
      ),
    );
  }
}
