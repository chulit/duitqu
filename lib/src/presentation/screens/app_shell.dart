import 'package:flutter/material.dart';

import '../../data/backup_service.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transfer_service.dart';
import '../l10n/app_localizations.dart';
import '../quick_add_defaults.dart';
import 'accounts_screen.dart';
import 'add_transaction_sheet.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'stats_screen.dart';

/// Kerangka aplikasi: bottom navigation 4 tab + FAB catat kilat.
/// Semua tab berbagi repository yang sama; daftar transaksi reaktif
/// lewat [TransactionRepository.watch] sehingga tidak perlu refresh manual.
class AppShell extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransferService transferService;
  final BackupService backup;
  final QuickAddDefaults defaults;

  const AppShell({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.transferService,
    required this.backup,
    required this.defaults,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  Future<void> _openAdd() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddTransactionSheet(
        txRepo: widget.txRepo,
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        transferService: widget.transferService,
        defaults: widget.defaults,
      ),
    );
    // Daftar reaktif via watch(); tidak perlu setState manual.
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            txRepo: widget.txRepo,
            accountRepo: widget.accountRepo,
            categoryRepo: widget.categoryRepo,
            transferService: widget.transferService,
            defaults: widget.defaults,
            onAdd: _openAdd,
          ),
          StatsScreen(txRepo: widget.txRepo, categoryRepo: widget.categoryRepo),
          AccountsScreen(
            accountRepo: widget.accountRepo,
            txRepo: widget.txRepo,
          ),
          MoreScreen(categoryRepo: widget.categoryRepo, backup: widget.backup),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: t.navHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_rounded),
            label: t.navStats,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.wallet_rounded),
            label: t.navAccounts,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_rounded),
            label: t.navMore,
          ),
        ],
      ),
    );
  }
}
