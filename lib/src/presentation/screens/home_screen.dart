import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/summary_service.dart';
import '../../domain/services/transfer_service.dart';
import '../category_icons.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../quick_add_defaults.dart';
import '../theme.dart';
import '../widgets/hero_art.dart';
import 'add_transaction_sheet.dart';

const _budgetKey = 'duitqu.monthly_budget';

/// Beranda ala mockup: sapaan, hero saldo, statistik, budget, transaksi terbaru.
class HomeScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransferService transferService;
  final QuickAddDefaults defaults;
  final VoidCallback onAdd;
  final VoidCallback onOpenInbox;
  final VoidCallback onSeeAll;

  const HomeScreen({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.transferService,
    required this.defaults,
    required this.onAdd,
    required this.onOpenInbox,
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
  Stream<List<Transaction>>? _txStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _txStream = widget.txRepo.watch(
      TransactionQuery(
        dateFrom: DateTime(now.year, now.month),
        dateTo: DateTime(
          now.year,
          now.month + 1,
        ).subtract(const Duration(milliseconds: 1)),
      ),
    );
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepo.list();
    final accs = await widget.accountRepo.list();
    int? budget;
    try {
      final prefs = await SharedPreferences.getInstance();
      budget = prefs.getInt(_budgetKey);
    } catch (_) {
      // SharedPreferences tidak tersedia (mis. test): budget tetap null.
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
      _ready = true;
      _balanceFuture = _totalBalance();
    });
  }

  Future<void> _setBudget() async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: _budget?.toString() ?? '');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.setBudgetTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: t.budgetLabel,
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(t.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          children: [
            const SizedBox(height: 16),
            _Header(greeting: _greeting(t), onOpenInbox: widget.onOpenInbox),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: _balanceFuture,
              builder: (context, snap) => _HeroCard(
                balance: snap.data ?? 0,
                hidden: _balanceHidden,
                onToggleHide: () =>
                    setState(() => _balanceHidden = !_balanceHidden),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Transaction>>(
              stream: _txStream,
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                final summary = _summaryService.summarize(txs);
                final net = summary.income - summary.expense;
                return Column(
                  children: [
                    _StatsCard(
                      income: summary.income,
                      expense: summary.expense,
                      net: net,
                      hidden: _balanceHidden,
                    ),
                    const SizedBox(height: 12),
                    _BudgetCard(
                      expense: summary.expense,
                      budget: _budget,
                      onTap: _setBudget,
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: t.recentTransactions,
                      actionLabel: t.seeAll,
                      onAction: widget.onSeeAll,
                    ),
                    const SizedBox(height: 8),
                    if (txs.isEmpty)
                      _EmptyTransactions()
                    else
                      for (final tx in txs.take(5))
                        _TransactionRow(
                          tx: tx,
                          category: tx.categoryId == null
                              ? null
                              : _categories[tx.categoryId],
                          account: _accounts[tx.accountId],
                          onTap: () => _openEdit(tx),
                        ),
                  ],
                );
              },
            ),
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
  final VoidCallback onOpenInbox;

  const _Header({required this.greeting, required this.onOpenInbox});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: DuitQuTheme.primaryBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: DuitQuTheme.primaryBlue,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              Text(
                t.greetingQuestion,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: onOpenInbox,
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: DuitQuTheme.expense,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int balance;
  final bool hidden;
  final VoidCallback onToggleHide;

  const _HeroCard({
    required this.balance,
    required this.hidden,
    required this.onToggleHide,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DuitQuTheme.radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B9BF5), Color(0xFF2F80ED), Color(0xFF1B5FC1)],
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
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 170,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: HeroArt(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 6),
                Text(
                  hidden ? 'Rp ••••••••' : formatRupiah(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.seeDetail,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
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
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int income;
  final int expense;
  final int net;
  final bool hidden;

  const _StatsCard({
    required this.income,
    required this.expense,
    required this.net,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String fmt(int v) => hidden ? 'Rp •••' : formatRupiah(v);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _StatItem(
              icon: Icons.arrow_upward_rounded,
              iconBg: DuitQuTheme.income.withValues(alpha: 0.12),
              iconColor: DuitQuTheme.income,
              label: t.income,
              value: fmt(income),
            ),
            _StatItem(
              icon: Icons.arrow_downward_rounded,
              iconBg: DuitQuTheme.expense.withValues(alpha: 0.12),
              iconColor: DuitQuTheme.expense,
              label: t.expense,
              value: fmt(expense),
            ),
            _StatItem(
              icon: Icons.account_balance_wallet_outlined,
              iconBg: DuitQuTheme.primaryBlue.withValues(alpha: 0.12),
              iconColor: DuitQuTheme.primaryBlue,
              label: t.remainingThisMonth,
              value: fmt(net),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DuitQuTheme.amountStyle(context, 15),
          ),
        ],
      ),
    );
  }
}

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
    final pct = budget == null || budget == 0
        ? 0.0
        : (expense / budget!).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(DuitQuTheme.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget == null
                          ? t.setBudgetPrompt
                          : t.budgetUsed((pct * 100).round()),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.7),
                        valueColor: const AlwaysStoppedAnimation(
                          DuitQuTheme.income,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
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
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            t.emptyHistory,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction tx;
  final Category? category;
  final Account? account;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.tx,
    required this.category,
    required this.account,
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
    final pillColor = isIncome
        ? DuitQuTheme.income
        : isExpense
        ? const Color(0xFFE5484D)
        : DuitQuTheme.primaryBlue;
    final pillBg = pillColor.withValues(alpha: 0.12);

    final title = tx.type == TransactionType.transfer
        ? t.transfer
        : (category?.name ?? '—');
    final subtitle = '${formatTanggal(tx.date, t)} · ${(account?.name ?? '')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
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
                      tx.merchant ?? title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense
                        ? '−'
                        : isIncome
                        ? '+'
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
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: pillColor,
                      ),
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
