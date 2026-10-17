import 'package:flutter/material.dart';

import '../../data/backup_service.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import '../locale_store.dart';
import '../theme_mode_store.dart';
import '../../domain/services/financial_query_service.dart';
import '../../domain/services/transfer_service.dart';
import '../quick_add_defaults.dart';
import '../user_name_store.dart';
import '../widgets/chat_assistant_sheet.dart';
import '../widgets/floating_nav.dart';
import 'add_transaction_sheet.dart';
import 'all_transactions_screen.dart';
import 'chat_ai_screen.dart';
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
  final LocaleStore localeStore;

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
    required this.localeStore,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _chatOpen = false;
  late final UserNameStore _nameStore;
  late final ChatAssistantController _chatController;

  @override
  void initState() {
    super.initState();
    _nameStore = UserNameStore();
    _chatController = ChatAssistantController(
      onSave: (parsed) => _openAdd(prefill: parsed),
      txRepo: widget.txRepo,
      queryService:
          FinancialQueryService(widget.txRepo, widget.categoryRepo),
      candidateRepo: widget.candidateRepo,
      categoryRepo: widget.categoryRepo,
      accountRepo: widget.accountRepo,
      onQuickAddType: (type) => _openAdd(type: type),
      onConfirmDelete: (title, body) async {
        final t = AppLocalizations.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t.deleteAction),
              ),
            ],
          ),
        );
        return ok == true;
      },
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
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

  /// Tombol chat tengah: buka bottom sheet.
  void _openChat() => setState(() => _chatOpen = true);

  void _closeChat() => setState(() => _chatOpen = false);

  /// Tombol expand di sheet: tutup sheet lalu buka halaman penuh.
  /// Riwayat chat dilanjutkan karena controller-nya sama.
  void _expandChat() {
    _closeChat();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatAiScreen(
          controller: _chatController,
          nameStore: _nameStore,
        ),
      ),
    );
  }

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
      InsightScreen(
        txRepo: widget.txRepo,
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        transferService: widget.transferService,
        defaults: widget.defaults,
      ),
      const GoalsScreen(),
      ProfileScreen(
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        txRepo: widget.txRepo,
        backup: widget.backup,
        themeStore: widget.themeStore,
        localeStore: widget.localeStore,
        nameStore: _nameStore,
      ),
    ];
    // Sheet chat: compact full-width, bawahnya nempel flush ke navbar
    // ("full nyambung"): tidak ada margin/jarak.
    // Backdrop meredupkan konten; "dock" putih di belakang navbar membuat
    // seluruh area bawah (sheet + navbar) satu permukaan putih tersambung.
    //
    // NOTE: Scaffold resizeToAvoidBottomInset=true (default), jadi saat
    // keyboard terbuka Stack sudah menyusut — sheetBottom tetap 90 agar
    // tidak ada gap ganda (bug: viewInsets ditambah padahal Stack sudah
    // di atas keyboard).
    final sheetBottom = 90.0;
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          if (_chatOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeChat,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ),
            // Dock putih di belakang navbar: menutupi backdrop di area
            // samping & bawah navbar.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 112,
              child: Container(color: surface),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: sheetBottom,
              // Material: sheet butuh Material ancestor (TextField, InkWell).
              child: Material(
                type: MaterialType.transparency,
                child: ChatAssistantSheet(
                  controller: _chatController,
                  onExpand: _expandChat,
                  onClose: _closeChat,
                  onViewTransaction: (_) {
                    _closeChat();
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
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: FloatingNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        onChatTap: _openChat,
      ),
    );
  }
}
