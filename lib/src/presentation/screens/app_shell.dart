import 'package:flutter/material.dart';

import '../../data/backup_service.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transfer_service.dart';
import '../quick_add_defaults.dart';
import '../widgets/chat_sheet.dart';
import '../widgets/floating_nav.dart';
import 'add_transaction_sheet.dart';
import 'all_transactions_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'insight_screen.dart';
import 'profile_screen.dart';

/// Kerangka aplikasi ala mockup: 4 tab + pil chat AI mengambang.
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

  Future<void> _openAdd({QuickParse? prefill}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddTransactionSheet(
        txRepo: widget.txRepo,
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        transferService: widget.transferService,
        defaults: widget.defaults,
        initialAmount: prefill?.amount,
        initialNote: prefill?.description,
      ),
    );
    if (changed == true) setState(() {});
  }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatSheet(onSave: (parsed) => _openAdd(prefill: parsed)),
    );
  }

  void _openInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InboxScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        txRepo: widget.txRepo,
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        transferService: widget.transferService,
        defaults: widget.defaults,
        onAdd: () => _openAdd(),
        onOpenInbox: _openInbox,
        onSeeAll: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AllTransactionsScreen(
                txRepo: widget.txRepo,
                accountRepo: widget.accountRepo,
                categoryRepo: widget.categoryRepo,
                transferService: widget.transferService,
                defaults: widget.defaults,
              ),
            ),
          );
        },
      ),
      InsightScreen(txRepo: widget.txRepo, categoryRepo: widget.categoryRepo),
      const GoalsScreen(),
      ProfileScreen(
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        txRepo: widget.txRepo,
        backup: widget.backup,
      ),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: FloatingNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        onChatTap: _openChat,
      ),
    );
  }
}
