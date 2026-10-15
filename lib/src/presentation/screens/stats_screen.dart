import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/summary_service.dart';
import '../category_icons.dart';
import '../l10n/app_localizations.dart';
import '../format.dart';
import '../theme.dart';

/// Statistik bulanan: ringkasan arus kas + breakdown per kategori.
class StatsScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final CategoryRepository categoryRepo;

  const StatsScreen({
    super.key,
    required this.txRepo,
    required this.categoryRepo,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _summaryService = SummaryService();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _categories = <int, Category>{};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepo.list();
    if (!mounted) return;
    setState(() {
      _categories
        ..clear()
        ..addEntries(
          cats.where((c) => c.id != null).map((c) => MapEntry(c.id!, c)),
        );
      _ready = true;
    });
  }

  DateTime get _monthStart => DateTime(_month.year, _month.month);
  DateTime get _monthEnd => DateTime(
    _month.year,
    _month.month + 1,
  ).subtract(const Duration(milliseconds: 1));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.navStats)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Transaction>>(
              stream: widget.txRepo.watch(
                TransactionQuery(dateFrom: _monthStart, dateTo: _monthEnd),
              ),
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                final summary = _summaryService.summarize(txs);
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    children: [
                      _MonthNav(
                        month: _month,
                        onPrev: () => setState(() {
                          _month = DateTime(_month.year, _month.month - 1);
                        }),
                        onNext: () => setState(() {
                          _month = DateTime(_month.year, _month.month + 1);
                        }),
                      ),
                      const SizedBox(height: 12),
                      _CashFlowCard(
                        income: summary.income,
                        expense: summary.expense,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.topCategories,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _CategoryBreakdown(txs: txs, categories: _categories),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthNav({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: onPrev,
            ),
            Expanded(
              child: Text(
                '${t.longMonth(month.month)} ${month.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu arus kas: bar pemasukan vs pengeluaran + selisih.
class _CashFlowCard extends StatelessWidget {
  final int income;
  final int expense;

  const _CashFlowCard({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxV = (income > expense ? income : expense);
    final net = income - expense;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BarRow(
              label: t.income,
              amount: income,
              fraction: maxV == 0 ? 0 : income / maxV,
              color: DuitQuTheme.incomeColor(context),
            ),
            const SizedBox(height: 12),
            _BarRow(
              label: t.expense,
              amount: expense,
              fraction: maxV == 0 ? 0 : expense / maxV,
              color: DuitQuTheme.expenseColor(context),
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.net,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  '${net >= 0 ? '+' : '−'}${formatRupiah(net.abs())}',
                  style: DuitQuTheme.amountStyle(
                    context,
                    18,
                    color: net >= 0
                        ? DuitQuTheme.incomeColor(context)
                        : DuitQuTheme.expenseColor(context),
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int amount;
  final double fraction;
  final Color color;

  const _BarRow({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              formatRupiah(amount),
              style: DuitQuTheme.amountStyle(context, 15, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Breakdown pengeluaran per kategori dengan progress bar.
class _CategoryBreakdown extends StatelessWidget {
  final List<Transaction> txs;
  final Map<int, Category> categories;

  const _CategoryBreakdown({required this.txs, required this.categories});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byCat = <int, int>{};
    for (final tx in txs) {
      if (tx.type != TransactionType.expense || tx.categoryId == null) {
        continue;
      }
      byCat[tx.categoryId!] = (byCat[tx.categoryId!] ?? 0) + tx.amount;
    }
    if (byCat.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              AppLocalizations.of(context).noTransactionsThisMonth,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxV = entries.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final e in entries)
              _CategoryRow(
                category: categories[e.key],
                amount: e.value,
                fraction: maxV == 0 ? 0 : e.value / maxV,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category? category;
  final int amount;
  final double fraction;

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final catColor = category == null
        ? scheme.onSurfaceVariant
        : Color(category!.color);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              categoryIcon(category?.icon),
              color: catColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category?.name ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      formatRupiah(amount),
                      style: DuitQuTheme.amountStyle(context, 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    valueColor: AlwaysStoppedAnimation(catColor),
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
