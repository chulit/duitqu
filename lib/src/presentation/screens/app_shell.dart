import 'package:flutter/material.dart';

import '../../data/backup_service.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../theme_mode_store.dart';
import '../../domain/services/financial_query_service.dart';
import '../../domain/services/transfer_service.dart';
import '../quick_add_defaults.dart';
import '../user_name_store.dart';
import '../widgets/chat_assistant_sheet.dart';
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
  final CandidateRepository candidateRepo;
  final TransferService transferService;
  final BackupService backup;
  final QuickAddDefaults defaults;
  final ThemeModeStore themeStore;

  const AppShell({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.candidateRepo,
    required this.transferService,
    required this.backup,
    required this.defaults,
    required this.themeStore,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _chatOpen = false;
  late final UserNameStore _nameStore;

  @override
  void initState() {
    super.initState();
    _nameStore = UserNameStore();
  }

  @override
  void dispose() {
    _nameStore.dispose();
    super.dispose();
  }

  Future<void> _openAdd({
    QuickParse? prefill,
    TransactionType? type,
  }) async {
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
        initialType: type,
      ),
    );
    if (changed == true) setState(() {});
  }

  /// Tombol chat tengah: buka bottom sheet (overlay di atas body,
  /// navbar tetap terlihat di bawahnya).
  void _openChat() => setState(() => _chatOpen = true);

  void _closeChat() => setState(() => _chatOpen = false);

  void _openInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InboxScreen(
          candidateRepo: widget.candidateRepo,
          txRepo: widget.txRepo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        txRepo: widget.txRepo,
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        candidateRepo: widget.candidateRepo,
        transferService: widget.transferService,
        defaults: widget.defaults,
        nameStore: _nameStore,
        onAdd: () => _openAdd(),
        onQuickAdd: (type) => _openAdd(type: type),
        onOpenInbox: _openInbox,
        onOpenInsight: () => setState(() => _index = 1),
        onSearch: () {
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
        themeStore: widget.themeStore,
        nameStore: _nameStore,
      ),
    ];
    return Scaffold(
      extendBody: true,
      // Saat chat terbuka, body diberi padding bawah setinggi navbar agar
      // bottom sheet diposisikan tepat di atas navbar (tidak menutupinya).
      body: Padding(
        padding: EdgeInsets.only(bottom: _chatOpen ? floatingNavFootprint : 0),
        child: Stack(
          children: [
            IndexedStack(index: _index, children: pages),
            // Overlay chat: background redup di body, navbar tetap terlihat.
            if (_chatOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeChat,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Positioned.fill(
                child: DraggableScrollableSheet(
                  initialChildSize: 0.82,
                  minChildSize: 0.45,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) => ChatAssistantSheet(
                    scrollController: scrollController,
                    onSave: (parsed) => _openAdd(prefill: parsed),
                    txRepo: widget.txRepo,
                    queryService: FinancialQueryService(
                      widget.txRepo,
                      widget.categoryRepo,
                    ),
                    candidateRepo: widget.candidateRepo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: FloatingNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        onChatTap: _openChat,
      ),
    );
  }
}
