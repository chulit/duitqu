import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../widgets/empty_state.dart';

/// Kunci budget bulanan — sama seperti yang dipakai home_screen.
const _budgetKey = 'duitqu.monthly_budget';

/// Insight ala mockup: header, pilih bulan, tab Pengeluaran/Pemasukan,
/// donut + breakdown kategori, dan kartu tips maskot dari data asli.
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

enum _Tab { expense, income }

class _InsightScreenState extends State<InsightScreen> {
  static const _summaryService = SummaryService();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _Tab _tab = _Tab.expense;
  final _categories = <int, Category>{};
  int? _budget;
  List<Transaction> _prevTxs = [];
  bool _ready = false;
  Stream<List<Transaction>>? _txStream;

  Stream<List<Transaction>> _makeStream() {
    return widget.txRepo.watch(
      TransactionQuery(
        dateFrom: DateTime(_month.year, _month.month),
        dateTo: DateTime(_month.year, _month.month + 1)
            .subtract(const Duration(milliseconds: 1)),
      ),
    );
  }

  TransactionQuery _prevMonthQuery() {
    final prev = DateTime(_month.year, _month.month - 1);
    return TransactionQuery(
      dateFrom: DateTime(prev.year, prev.month),
      dateTo: DateTime(prev.year, prev.month + 1)
          .subtract(const Duration(milliseconds: 1)),
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
    _loadPrevMonth();
  }

  void _setTab(_Tab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepo.list();
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
      _budget = budget;
      _ready = true;
    });
    _loadPrevMonth();
  }

  Future<void> _loadPrevMonth() async {
    final txs = await widget.txRepo.list(_prevMonthQuery());
    if (!mounted) return;
    setState(() => _prevTxs = txs);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isExpense = _tab == _Tab.expense;
    return Scaffold(
      appBar: AppBar(title: Text(t.insightTitle)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Transaction>>(
              stream: _txStream,
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                final byCat = isExpense
                    ? _summaryService.expenseByCategory(txs)
                    : _byCategory(txs, TransactionType.income);
                final prevByCat = isExpense
                    ? _summaryService.expenseByCategory(_prevTxs)
                    : _byCategory(_prevTxs, TransactionType.income);
                final entries = byCat.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final total = entries.fold<int>(0, (a, e) => a + e.value);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  children: [
                    _MonthNav(
                      month: _month,
                      onPrev: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                    ),
                    const SizedBox(height: 12),
                    _TabSwitch(
                      expenseLabel: t.expenseTab,
                      incomeLabel: t.incomeTab,
                      tab: _tab,
                      onChanged: _setTab,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          height: 220,
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
                                    _colorFor(i, entries[i].key),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isExpense
                                        ? t.expenseThisMonth
                                        : t.incomeTab,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatRupiah(total),
                                    style: DuitQuTheme.amountStyle(
                                      context,
                                      22,
                                    ),
                                  ),
                                  if (isExpense) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _budgetLine(t, total),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
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
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              for (var i = 0; i < entries.length; i++)
                                _CategoryRow(
                                  name: _categories[entries[i].key]?.name ??
                                      '—',
                                  icon: categoryIcon(
                                    _categories[entries[i].key]?.icon,
                                  ),
                                  amount: entries[i].value,
                                  total: total,
                                  color: _colorFor(i, entries[i].key),
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    MascotTipCard(
                      message: _tipMessage(t, byCat, prevByCat),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// Baris "48% dari budget"; '—' bila budget belum diatur.
  String _budgetLine(AppLocalizations t, int total) {
    final budget = _budget;
    if (budget == null || budget <= 0) return '— ${t.ofBudget}';
    return t.budgetPercent((total / budget * 100).round());
  }

  /// Warna segmen: pakai warna kategori bila ada, palet cadangan bila tidak.
  Color _colorFor(int index, int categoryId) {
    final cat = _categories[categoryId];
    if (cat != null) return Color(cat.color);
    return _palette[index % _palette.length];
  }

  static const _palette = [
    Color(0xFF2E9BFF), // biru
    Color(0xFFF2994A), // oranye
    Color(0xFF27AE60), // hijau
    Color(0xFF9B51E0), // ungu
    Color(0xFFEB5757), // merah
    Color(0xFF2D9CDB), // biru muda
  ];

  /// Agregasi nominal per kategori untuk satu tipe transaksi.
  static Map<int, int> _byCategory(
    Iterable<Transaction> txs,
    TransactionType type,
  ) {
    final out = <int, int>{};
    for (final tx in txs) {
      if (tx.type != type) continue;
      final catId = tx.categoryId;
      if (catId == null) continue;
      out[catId] = (out[catId] ?? 0) + tx.amount;
    }
    return out;
  }

  /// Pesan maskot dari data asli: kenaikan terbesar vs bulan lalu,
  /// kategori baru, atau pesan netral bila data kurang.
  String _tipMessage(
    AppLocalizations t,
    Map<int, int> cur,
    Map<int, int> prev,
  ) {
    if (cur.isEmpty) return t.insightNoData;

    String nameOf(int id) => _categories[id]?.name ?? '—';

    // Kenaikan persen terbesar di kategori yang sudah ada bulan lalu.
    String? upName;
    var upPct = 0;
    for (final e in cur.entries) {
      final p = prev[e.key] ?? 0;
      if (p <= 0) continue;
      final pct = ((e.value - p) / p * 100).round();
      if (pct > upPct) {
        upPct = pct;
        upName = nameOf(e.key);
      }
    }
    if (upName != null && upPct >= 1) {
      return _tab == _Tab.expense
          ? t.insightExpenseUp(upName, upPct)
          : t.insightIncomeUp(upName, upPct);
    }

    // Kategori yang baru muncul bulan ini: ambil nominal terbesar.
    MapEntry<int, int>? newest;
    for (final e in cur.entries) {
      if ((prev[e.key] ?? 0) > 0) continue;
      if (newest == null || e.value > newest.value) newest = e;
    }
    if (newest != null) {
      return t.insightNewCategory(
        nameOf(newest.key),
        formatRupiah(newest.value),
      );
    }

    return t.insightCalm;
  }
}

/// Pilih bulan ala mockup: "<  Juli 2025  >".
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

/// Segmented control ala mockup: pill biru untuk tab aktif, teks abu
/// untuk tab nonaktif.
class _TabSwitch extends StatelessWidget {
  final String expenseLabel;
  final String incomeLabel;
  final _Tab tab;
  final ValueChanged<_Tab> onChanged;

  const _TabSwitch({
    required this.expenseLabel,
    required this.incomeLabel,
    required this.tab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: expenseLabel,
              active: tab == _Tab.expense,
              onTap: () => onChanged(_Tab.expense),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: incomeLabel,
              active: tab == _Tab.income,
              onTap: () => onChanged(_Tab.income),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? DuitQuTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : DuitQuTheme.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// Baris kategori ala mockup: ikon tinted, nama + progress bar tipis,
/// persen dan nominal di kanan.
class _CategoryRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final int amount;
  final int total;
  final Color color;

  const _CategoryRow({
    required this.name,
    required this.icon,
    required this.amount,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
    final pct = (fraction * 100).round();
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
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: DuitQuTheme.amountStyle(
                  context,
                  14,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatRupiah(amount),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
