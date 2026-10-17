import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_candidate.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/summary_service.dart';
import '../../domain/services/transfer_service.dart';
import '../category_icons.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../quick_add_defaults.dart';
import '../theme.dart';
import '../user_name_store.dart';
import '../widgets/empty_state.dart';
import '../widgets/mascot_image.dart';
import 'add_transaction_sheet.dart';

const _budgetKey = 'duitqu.monthly_budget';

/// Beranda ala mockup baru: header sapaan + search, hero saldo gradient,
/// 4 tombol aksi cepat, kartu budget, transaksi terbaru, dan kartu CTA.
/// Read-only terhadap data: baca lewat repository, tulis hanya via
/// TransactionRepository. Angka mockup tidak di-hardcode.
class HomeScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final CandidateRepository candidateRepo;
  final TransferService transferService;
  final QuickAddDefaults defaults;
  final UserNameStore nameStore;
  final VoidCallback onAdd;
  final ValueChanged<TransactionType> onQuickAdd;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenInsight;
  final VoidCallback onSearch;
  final VoidCallback onSeeAll;

  const HomeScreen({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.candidateRepo,
    required this.transferService,
    required this.defaults,
    required this.nameStore,
    required this.onAdd,
    required this.onQuickAdd,
    required this.onOpenInbox,
    required this.onOpenInsight,
    required this.onSearch,
    required this.onSeeAll,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _summaryService = SummaryService();

  final _categories = <int, Category>{};
  final _accounts = <int, Account>{};
  bool _balanceHidden = false;
  int? _budget;
  bool _ready = false;
  Future<int>? _balanceFuture;
  Future<int>? _pendingInboxFuture;
  Stream<List<Transaction>>? _monthStream;
  Stream<List<Transaction>>? _recentStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStream = widget.txRepo.watch(
      TransactionQuery(
        dateFrom: DateTime(now.year, now.month),
        dateTo: DateTime(
          now.year,
          now.month + 1,
        ).subtract(const Duration(milliseconds: 1)),
      ),
    );
    // Transaksi terbaru keseluruhan (sudah urut tanggal desc).
    _recentStream = widget.txRepo.watch(const TransactionQuery());
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepo.list();
    final accs = await widget.accountRepo.list();
    int? budget;
    int pending = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      budget = prefs.getInt(_budgetKey);
    } catch (_) {
      // SharedPreferences tidak tersedia (mis. test): budget tetap null.
    }
    try {
      final list = await widget.candidateRepo
          .listByStatus(CandidateStatus.needsReview);
      pending = list.length;
    } catch (_) {
      // Kandidat tidak tersedia: dot notif disembunyikan.
    }
    if (!mounted) return;
    setState(() {
      _categories
        ..clear()
        ..addEntries(
          cats.where((c) => c.id != null).map((c) => MapEntry(c.id!, c)),
        );
      _accounts
        ..clear()
        ..addEntries(
          accs.where((a) => a.id != null).map((a) => MapEntry(a.id!, a)),
        );
      _budget = budget;
      _pendingInboxFuture = Future.value(pending);
      _ready = true;
      _balanceFuture = _totalBalance();
    });
  }

  Future<void> _setBudget() async {
    final t = AppLocalizations.of(context);
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => _BudgetInputDialog(initial: _budget, t: t),
    );
    if (value == null || value <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_budgetKey, value);
    } catch (_) {
      return;
    }
    if (mounted) setState(() => _budget = value);
  }

  String _greeting(AppLocalizations t) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) return t.goodMorning;
    if (h >= 11 && h < 15) return t.goodAfternoon;
    if (h >= 15 && h < 18) return t.goodEvening;
    return t.goodNight;
  }

  /// Emoji sapaan sesuai jam (tanpa koma di akhir).
  String _greetingEmoji() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 15) return '\u2600\uFE0F';
    if (h >= 15 && h < 18) return '\u{1F305}';
    return '\u{1F319}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            SizedBox(height: topPad + 12),
            _Header(
              greeting: _greeting(t),
              emoji: _greetingEmoji(),
              nameStore: widget.nameStore,
              pendingInbox: _pendingInboxFuture,
              onOpenInbox: widget.onOpenInbox,
              onSearch: widget.onSearch,
            ),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: _balanceFuture,
              builder: (context, snap) => _HeroCard(
                balance: snap.data ?? 0,
                hidden: _balanceHidden,
                onToggleHide: () =>
                    setState(() => _balanceHidden = !_balanceHidden),
                onSeeDetails: widget.onSeeAll,
              ),
            ),
            const SizedBox(height: 16),
            _QuickActions(
              onIncome: () => widget.onQuickAdd(TransactionType.income),
              onExpense: () => widget.onQuickAdd(TransactionType.expense),
              onTransactions: widget.onSeeAll,
              onReport: widget.onOpenInsight,
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Transaction>>(
              stream: _monthStream,
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                final summary = _summaryService.summarize(txs);
                return _BudgetCard(
                  expense: summary.expense,
                  budget: _budget,
                  onTap: _setBudget,
                );
              },
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: t.recentTransactions,
              actionLabel: t.seeAll,
              onAction: widget.onSeeAll,
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Transaction>>(
              stream: _recentStream,
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                if (txs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: EmptyState(
                      mascot: const MascotImage.emptyTransactions(size: 140),
                      title: t.noTransactionsTitle,
                      subtitle: t.noTransactionsSubtitle,
                      actionLabel: t.recordNow,
                      onAction: widget.onAdd,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final tx in txs.take(5))
                      _TransactionRow(
                        tx: tx,
                        category: tx.categoryId == null
                            ? null
                            : _categories[tx.categoryId],
                        onTap: () => _openEdit(tx),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _CtaCard(onTap: widget.onAdd),
          ],
        ),
      ),
    );
  }

  Future<int> _totalBalance() async {
    var total = 0;
    for (final a in _accounts.values) {
      total += await widget.accountRepo.balance(a.id!);
    }
    return total;
  }

  Future<void> _openEdit(Transaction tx) async {
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
        existing: tx,
      ),
    );
    if (changed == true) setState(() {});
  }
}

class _Header extends StatelessWidget {
  final String greeting;
  final String emoji;
  final UserNameStore nameStore;
  final Future<int>? pendingInbox;
  final VoidCallback onOpenInbox;
  final VoidCallback onSearch;

  const _Header({
    required this.greeting,
    required this.emoji,
    required this.nameStore,
    required this.pendingInbox,
    required this.onOpenInbox,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFE3F2FD),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: const MascotImage.avatar(size: 48),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ValueListenableBuilder<String?>(
            valueListenable: nameStore,
            builder: (context, name, _) {
              final hasName = name != null && name.isNotEmpty;
              if (!hasName) {
                // Fallback tanpa nama: sapaan satu baris (tanpa koma).
                final clean =
                    greeting.replaceAll(RegExp(r',\s*$'), '');
                return Text(
                  '$clean $emoji',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: DuitQuTheme.ink,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 13,
                      color: DuitQuTheme.inkSoft,
                    ),
                  ),
                  Text(
                    '$name! $emoji',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DuitQuTheme.ink,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        FutureBuilder<int>(
          future: pendingInbox,
          builder: (context, snap) {
            final hasPending = (snap.data ?? 0) > 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: DuitQuTheme.ink,
                  ),
                  onPressed: onOpenInbox,
                ),
                if (hasPending)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DuitQuTheme.expense,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 10, height: 10),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.search_rounded, color: scheme.onSurface),
          onPressed: onSearch,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int balance;
  final bool hidden;
  final VoidCallback onToggleHide;
  final VoidCallback onSeeDetails;

  const _HeroCard({
    required this.balance,
    required this.hidden,
    required this.onToggleHide,
    required this.onSeeDetails,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      height: 172,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DuitQuTheme.radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5EB3FF), Color(0xFF2E9BFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: DuitQuTheme.primaryBlue.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Awan dekorasi ala mockup.
          Positioned(
            right: -30,
            bottom: -10,
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/mascot/hero/cloud.webp',
                width: 220,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Maskot hero agak nongol ke bawah ala mockup.
          Positioned(
            right: 8,
            bottom: -16,
            child: const MascotImage.hero(size: 128),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            t.totalBalance,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onToggleHide,
                            child: Icon(
                              hidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // FittedBox: saldo besar mengecil otomatis, tidak
                      // overflow tertutup maskot.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          hidden
                              ? 'Rp \u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022'
                              : formatRupiah(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onSeeDetails,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.seeDetails,
                                style: const TextStyle(
                                  color: DuitQuTheme.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: DuitQuTheme.primaryBlue,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 4 tombol aksi cepat dalam satu kartu ala mockup.
class _QuickActions extends StatelessWidget {
  final VoidCallback onIncome;
  final VoidCallback onExpense;
  final VoidCallback onTransactions;
  final VoidCallback onReport;

  const _QuickActions({
    required this.onIncome,
    required this.onExpense,
    required this.onTransactions,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: DuitQuTheme.cardDecoration(context),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          _QuickItem(
            icon: Icons.arrow_downward_rounded,
            color: DuitQuTheme.income,
            label: t.quickIncome,
            onTap: onIncome,
          ),
          _QuickItem(
            icon: Icons.arrow_upward_rounded,
            color: DuitQuTheme.expense,
            label: t.quickExpense,
            onTap: onExpense,
          ),
          _QuickItem(
            icon: Icons.receipt_long_rounded,
            color: DuitQuTheme.primaryBlue,
            label: t.quickTransactions,
            onTap: onTransactions,
          ),
          _QuickItem(
            icon: Icons.pie_chart_rounded,
            color: const Color(0xFF8B5CF6),
            label: t.quickReport,
            onTap: onReport,
          ),
        ],
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DuitQuTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu budget ala mockup: ikon dompet + judul + "Lihat semua",
/// nominal terpakai "dari" total, progress bar hijau + persen.
class _BudgetCard extends StatelessWidget {
  final int expense;
  final int? budget;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.expense,
    required this.budget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasBudget = budget != null && budget! > 0;
    final pct = hasBudget ? (expense / budget!).clamp(0.0, 1.0) : 0.0;
    const purple = Color(0xFF8B5CF6);
    return Container(
      decoration: DuitQuTheme.cardDecoration(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(DuitQuTheme.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: purple.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: purple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.monthlyBudget,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DuitQuTheme.ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onTap,
                    child: Row(
                      children: [
                        Text(
                          t.seeAll,
                          style: const TextStyle(
                            color: DuitQuTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: DuitQuTheme.primaryBlue,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Aturan kejujuran data: tanpa budget -> '—'.
              Text(
                hasBudget ? formatRupiah(expense) : '—',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: DuitQuTheme.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // ignore: avoid_redundant_argument_values
                t.budgetFrom(hasBudget ? formatRupiah(budget!) : '—'),
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 10,
                        child: Stack(
                          children: [
                            Container(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.7),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: pct,
                              child: Container(
                                color: const Color(0xFF34D399),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hasBudget ? '${(pct * 100).round()}%' : '—',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog input budget: controller dimiliki dialog sendiri agar dispose
/// terjadi tepat saat route dialog dibuang (tidak saat animasi pop).
class _BudgetInputDialog extends StatefulWidget {
  final int? initial;
  final AppLocalizations t;

  const _BudgetInputDialog({required this.initial, required this.t});

  @override
  State<_BudgetInputDialog> createState() => _BudgetInputDialogState();
}

class _BudgetInputDialogState extends State<_BudgetInputDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.t.setBudgetTitle),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: widget.t.budgetLabel,
          prefixText: 'Rp ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.t.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(_ctrl.text.trim())),
          child: Text(widget.t.save),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: DuitQuTheme.ink,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onAction,
          child: Row(
            children: [
              Text(
                actionLabel,
                style: const TextStyle(
                  color: DuitQuTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: DuitQuTheme.primaryBlue,
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction tx;
  final Category? category;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.tx,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isExpense = tx.type == TransactionType.expense;
    final isIncome = tx.type == TransactionType.income;
    final catColor = category == null
        ? scheme.onSurfaceVariant
        : Color(category!.color);

    final title = tx.type == TransactionType.transfer
        ? t.transfer
        : (tx.merchant ?? category?.name ?? '—');
    final dateLabel = _relativeDate(tx.date, t);
    final chipLabel = tx.type == TransactionType.transfer
        ? t.transfer
        : (category?.name ?? '—');
    final chipColor = isIncome
        ? DuitQuTheme.income
        : isExpense
            ? DuitQuTheme.expense
            : DuitQuTheme.primaryBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                tx.type == TransactionType.transfer
                    ? Icons.swap_horiz_rounded
                    : categoryIcon(category?.icon),
                color: catColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: DuitQuTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        ' \u00B7 ',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: chipColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            chipLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: chipColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isExpense
                  ? '\u2212 '
                  : isIncome
                      ? '+ '
                      : ''}${formatRupiah(tx.amount)}',
              style: DuitQuTheme.amountStyle(
                context,
                15,
                color: isExpense
                    ? scheme.onSurface
                    : isIncome
                        ? DuitQuTheme.income
                        : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime d, AppLocalizations t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return t.today;
    if (day == today.subtract(const Duration(days: 1))) return t.yesterday;
    return formatTanggal(d, t);
  }
}

/// Kartu CTA bawah ala mockup: maskot ide + ajakan + tombol panah.
class _CtaCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CtaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(DuitQuTheme.radius),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const MascotImage.idea(size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.ctaTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: DuitQuTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.ctaSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DuitQuTheme.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: DuitQuTheme.primaryBlue,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
