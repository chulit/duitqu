import 'package:flutter/material.dart';

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
import '../widgets/donut_chart.dart';
import '../widgets/empty_state.dart';
import '../widgets/mascot_image.dart';
import 'all_transactions_screen.dart';

/// Insight ala mockup: header, pilih bulan, tab Pengeluaran/Pemasukan,
/// donut + breakdown kategori, dan kartu tips maskot dari data asli.
class InsightScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransferService transferService;
  final QuickAddDefaults defaults;

  const InsightScreen({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.transferService,
    required this.defaults,
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
  List<Transaction> _prevTxs = [];
  bool _ready = false;
  Stream<List<Transaction>>? _txStream;
  // Total per bulan Jan..bulan terpilih untuk tab aktif (tren).
  List<int> _trendTotals = [];

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
    _loadTrend();
  }

  void _setTab(_Tab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _loadTrend();
  }

  /// Muat total per bulan (Jan s.d. bulan terpilih) untuk tab aktif.
  Future<void> _loadTrend() async {
    final year = _month.year;
    final tab = _tab;
    final txs = await widget.txRepo.list(
      TransactionQuery(
        dateFrom: DateTime(year, 1, 1),
        dateTo: DateTime(year, _month.month + 1).subtract(
          const Duration(milliseconds: 1),
        ),
      ),
    );
    final type = tab == _Tab.expense
        ? TransactionType.expense
        : TransactionType.income;
    final totals = List<int>.filled(_month.month, 0);
    for (final tx in txs) {
      if (tx.type != type) continue;
      final m = tx.date.month;
      if (m >= 1 && m <= _month.month) totals[m - 1] += tx.amount;
    }
    if (!mounted) return;
    setState(() {
      _trendTotals = totals;
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
    _loadPrevMonth();
    _loadTrend();
  }

  Future<void> _loadPrevMonth() async {
    final txs = await widget.txRepo.list(_prevMonthQuery());
    if (!mounted) return;
    setState(() => _prevTxs = txs);
  }

  /// Urutkan entri kategori: nominal desc, "Lainnya" selalu terakhir.
  List<MapEntry<int, int>> _sortedEntries(Map<int, int> byCat) {
    final entries = byCat.entries.toList();
    bool isOther(int id) =>
        (_categories[id]?.name ?? '').toLowerCase() == 'lainnya';
    entries.sort((a, b) {
      final aOther = isOther(a.key);
      final bOther = isOther(b.key);
      if (aOther != bOther) return aOther ? 1 : -1;
      return b.value.compareTo(a.value);
    });
    return entries;
  }

  /// Persen perubahan vs bulan lalu; null bila tidak bisa dihitung.
  int? _pctChange(int total, int prevTotal) {
    if (prevTotal <= 0) return null;
    return ((total - prevTotal) / prevTotal * 100).round();
  }

  /// Buka daftar transaksi untuk kategori + bulan ini.
  void _openCategory(BuildContext context, int categoryId) {
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
                final entries = _sortedEntries(byCat);
                final total = entries.fold<int>(0, (a, e) => a + e.value);
                final prevTotal = prevByCat.values.fold<int>(0, (a, v) => a + v);
                final pct = _pctChange(total, prevTotal);
                // Warna %: expense naik=merah (boros), turun=hijau (hemat);
                // income kebalikannya.
                final pctUp = (pct ?? 0) > 0;
                final pctGood = isExpense ? !pctUp : pctUp;
                final pctColor = pct == null
                    ? scheme.onSurfaceVariant
                    : pct == 0
                        ? scheme.onSurfaceVariant
                        : pctGood
                            ? const Color(0xFF27AE60)
                            : const Color(0xFFEB5757);

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
                    // Kartu ringkasan ala mockup: total + % vs bulan lalu + maskot.
                    _SummaryCard(
                      title: isExpense ? t.totalExpense : t.totalIncome,
                      total: total,
                      pct: pct,
                      pctColor: pctColor,
                      pctUp: pctUp,
                      subtitle: t.fromLastMonth,
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      _EmptyInsight(t: t)
                    else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isExpense
                                    ? t.expensePerCategory
                                    : t.incomePerCategory,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 150,
                                    height: 150,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        DonutChart(
                                          values: [
                                            for (final e in entries)
                                              e.value.toDouble(),
                                          ],
                                          colors: [
                                            for (var i = 0;
                                                i < entries.length;
                                                i++)
                                              _colorFor(i, entries[i].key),
                                          ],
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              formatRupiahShort(total),
                                              style: DuitQuTheme.amountStyle(
                                                context,
                                                16,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isExpense
                                                  ? t.totalExpense
                                                  : t.totalIncome,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    scheme.onSurfaceVariant,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            Text(
                                              formatBulan(_month, t),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var i = 0;
                                            i < entries.length;
                                            i++)
                                          _LegendRow(
                                            name:
                                                _categories[entries[i].key]
                                                        ?.name ??
                                                    '—',
                                            icon: categoryIcon(
                                              _categories[entries[i].key]?.icon,
                                            ),
                                            amount: entries[i].value,
                                            total: total,
                                            color: _colorFor(
                                              i,
                                              entries[i].key,
                                            ),
                                            onTap: () => _openCategory(
                                              context,
                                              entries[i].key,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TrendCard(
                        title: isExpense ? t.trendExpense : t.trendIncome,
                        totals: _trendTotals,
                        selectedMonth: _month.month,
                        onBarTap: (m) {
                          final delta = m - _month.month;
                          if (delta != 0) _changeMonth(delta);
                        },
                      ),
                    ],
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


/// Kartu ringkasan ala mockup: label total, nominal besar,
/// persen perubahan vs bulan lalu, dan maskot di kanan.
class _SummaryCard extends StatelessWidget {
  final String title;
  final int total;
  final int? pct;
  final Color pctColor;
  final bool pctUp;
  final String subtitle;

  const _SummaryCard({
    required this.title,
    required this.total,
    required this.pct,
    required this.pctColor,
    required this.pctUp,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatRupiah(total),
                    style: DuitQuTheme.amountStyle(context, 28),
                  ),
                  const SizedBox(height: 8),
                  if (pct != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: pctColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            pctUp
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 14,
                            color: pctColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${pct!.abs()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: pctColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const MascotImage.tips(size: 88),
          ],
        ),
      ),
    );
  }
}

/// Baris legend ala mockup: ikon bulat berwarna, nama + nominal,
/// persen di kanan. Bisa di-tap.
class _LegendRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final int amount;
  final int total;
  final Color color;
  final VoidCallback onTap;

  const _LegendRow({
    required this.name,
    required this.icon,
    required this.amount,
    required this.total,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total <= 0 ? 0 : (amount / total * 100).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            ),
            Text(
              '$pct%',
              style: DuitQuTheme.amountStyle(
                context,
                14,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar chart tren bulanan: Jan s.d. bulan terpilih.
/// Tap bar untuk pindah ke bulan tersebut.
class _TrendCard extends StatelessWidget {
  final String title;
  final List<int> totals;
  final int selectedMonth;
  final ValueChanged<int> onBarTap;

  const _TrendCard({
    required this.title,
    required this.totals,
    required this.selectedMonth,
    required this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxVal = totals.fold<int>(0, (a, v) => v > a ? v : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < totals.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onBarTap(i + 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (i + 1 == selectedMonth &&
                                totals[i] > 0)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  formatRupiahShort(totals[i]),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: DuitQuTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            Container(
                              height: maxVal <= 0
                                  ? 8
                                  : (totals[i] / maxVal * 120)
                                          .clamp(8.0, 120.0),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: i + 1 == selectedMonth
                                    ? DuitQuTheme.primaryBlue
                                    : DuitQuTheme.primaryBlue.withValues(
                                        alpha: 0.18,
                                      ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.shortMonth(i + 1),
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                                fontWeight: i + 1 == selectedMonth
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
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
    );
  }
}

/// Empty state dengan maskot bila bulan ini belum ada transaksi.
class _EmptyInsight extends StatelessWidget {
  final AppLocalizations t;

  const _EmptyInsight({required this.t});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const MascotImage.emptyTransactions(size: 120),
            const SizedBox(height: 16),
            Text(
              t.noTransactionsThisMonth,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
