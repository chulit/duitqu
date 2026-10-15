import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/summary_service.dart';
import '../category_icons.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/donut_chart.dart';

/// Insight ala mockup: donut pengeluaran + breakdown kategori.
class InsightScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final CategoryRepository categoryRepo;

  const InsightScreen({
    super.key,
    required this.txRepo,
    required this.categoryRepo,
  });

  @override
  State<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends State<InsightScreen> {
  static const _summaryService = SummaryService();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _categories = <int, Category>{};
  bool _ready = false;
  Stream<List<Transaction>>? _txStream;

  Stream<List<Transaction>> _makeStream() {
    final monthStart = DateTime(_month.year, _month.month);
    final monthEnd = DateTime(
      _month.year,
      _month.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    return widget.txRepo.watch(
      TransactionQuery(dateFrom: monthStart, dateTo: monthEnd),
    );
  }

  @override
  void initState() {
    super.initState();
    _txStream = _makeStream();
    _load();
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _txStream = _makeStream();
    });
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.insightTitle)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Transaction>>(
              stream: _txStream,
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                final summary = _summaryService.summarize(txs);
                final byCat = <int, int>{};
                for (final tx in txs) {
                  if (tx.type != TransactionType.expense ||
                      tx.categoryId == null) {
                    continue;
                  }
                  byCat[tx.categoryId!] =
                      (byCat[tx.categoryId!] ?? 0) + tx.amount;
                }
                final entries = byCat.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final totalExpense = summary.expense;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  children: [
                    _MonthNav(
                      month: _month,
                      onPrev: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 210,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  DonutChart(
                                    values: [
                                      for (
                                        var i = 0;
                                        i < entries.length && i < 6;
                                        i++
                                      )
                                        entries[i].value.toDouble(),
                                    ],
                                    colors: [
                                      for (
                                        var i = 0;
                                        i < entries.length && i < 6;
                                        i++
                                      )
                                        _segmentColor(i),
                                    ],
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        t.expenseThisMonth,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatRupiah(totalExpense),
                                        style: DuitQuTheme.amountStyle(
                                          context,
                                          20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(
                            child: Text(
                              t.noTransactionsThisMonth,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              for (var i = 0; i < entries.length; i++)
                                _CategoryRow(
                                  category: _categories[entries[i].key],
                                  amount: entries[i].value,
                                  total: totalExpense,
                                  color: _segmentColor(i),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  static const _palette = [
    Color(0xFFF2994A), // oranye
    Color(0xFF2F80ED), // biru
    Color(0xFF9B51E0), // ungu
    Color(0xFF27AE60), // hijau
    Color(0xFFEB5757), // merah
    Color(0xFFBDBDBD), // abu
  ];

  Color _segmentColor(int i) => _palette[i % _palette.length];
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrev,
        ),
        Text(
          '${t.longMonth(month.month)} ${month.year}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category? category;
  final int amount;
  final int total;
  final Color color;

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0 : (amount / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(categoryIcon(category?.icon), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category?.name ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  formatRupiah(amount),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$pct%',
            style: DuitQuTheme.amountStyle(context, 15, color: color),
          ),
        ],
      ),
    );
  }
}
