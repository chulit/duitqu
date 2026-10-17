import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../category_icons.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/chart_painters.dart';
import 'all_transactions_screen.dart';
import 'add_transaction_sheet.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/services/transfer_service.dart';
import '../quick_add_defaults.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Halaman detail kategori ala mockup: hero + banner perubahan +
/// perbandingan 6 bulan + perbandingan antar kategori + transaksi terbaru.
class CategoryDetailScreen extends StatefulWidget {
  final int categoryId;
  final DateTime month;
  final TransactionRepository txRepo;
  final CategoryRepository categoryRepo;
  final AccountRepository accountRepo;
  final TransferService transferService;
  final QuickAddDefaults defaults;

  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.month,
    required this.txRepo,
    required this.categoryRepo,
    required this.accountRepo,
    required this.transferService,
    required this.defaults,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  Category? _category;
  List<Transaction> _txs = [];
  List<Transaction> _prevTxs = [];
  List<Transaction> _trendTxs = [];
  Map<int, Category> _categories = {};
  bool _ready = false;
  int _trendRange = 6;

  DateTime get _month => widget.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepo.list();
    final monthStart = DateTime(_month.year, _month.month);
    final monthEnd = DateTime(_month.year, _month.month + 1)
        .subtract(const Duration(milliseconds: 1));
    final txs = await widget.txRepo.list(
      TransactionQuery(dateFrom: monthStart, dateTo: monthEnd),
    );
    final prev = DateTime(_month.year, _month.month - 1);
    final prevTxs = await widget.txRepo.list(
      TransactionQuery(
        dateFrom: DateTime(prev.year, prev.month),
        dateTo: DateTime(prev.year, prev.month + 1)
            .subtract(const Duration(milliseconds: 1)),
      ),
    );
    // Tren: N bulan terakhir untuk kategori ini.
    final trendStart =
        DateTime(_month.year, _month.month - _trendRange + 1);
    final trendTxs = await widget.txRepo.list(
      TransactionQuery(
        dateFrom: DateTime(trendStart.year, trendStart.month),
        dateTo: monthEnd,
      ),
    );
    if (!mounted) return;
    setState(() {
      _categories = {
        for (final c in cats)
          if (c.id != null) c.id!: c,
      };
      _category = _categories[widget.categoryId];
      _txs = txs;
      _prevTxs = prevTxs;
      _trendTxs = trendTxs;
      _ready = true;
    });
  }

  void _setTrendRange(int range) {
    if (_trendRange == range) return;
    setState(() => _trendRange = range);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (!_ready) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final catName = _category?.name ?? '—';
    final catIcon = categoryIcon(_category?.icon);
    final catColor = _category != null
        ? Color(_category!.color)
        : scheme.primary;

    // Total kategori ini bulan ini & bulan lalu.
    var total = 0;
    for (final tx in _txs) {
      if (tx.categoryId == widget.categoryId &&
          tx.type == TransactionType.expense) {
        total += tx.amount;
      }
    }
    var prevTotal = 0;
    for (final tx in _prevTxs) {
      if (tx.categoryId == widget.categoryId &&
          tx.type == TransactionType.expense) {
        prevTotal += tx.amount;
      }
    }
    // Total pengeluaran semua kategori (untuk %).
    var allExpense = 0;
    for (final tx in _txs) {
      if (tx.type == TransactionType.expense) allExpense += tx.amount;
    }
    final sharePct =
        allExpense <= 0 ? 0 : (total / allExpense * 100).round();
    final pctChange = prevTotal <= 0
        ? null
        : ((total - prevTotal) / prevTotal * 100).round();
    final up = (pctChange ?? 0) >= 0;

    // Tren bulanan kategori ini.
    final trendStart =
        DateTime(_month.year, _month.month - _trendRange + 1);
    final trendVals = List<int>.filled(_trendRange, 0);
    final trendLabels = <String>[];
    for (var i = 0; i < _trendRange; i++) {
      final d = DateTime(trendStart.year, trendStart.month + i);
      trendLabels.add(_shortMonth(d.month, t));
    }
    for (final tx in _trendTxs) {
      if (tx.categoryId != widget.categoryId ||
          tx.type != TransactionType.expense) {
        continue;
      }
      final idx = (tx.date.year - trendStart.year) * 12 +
          (tx.date.month - trendStart.month);
      if (idx >= 0 && idx < _trendRange) trendVals[idx] += tx.amount;
    }

    // Perbandingan antar kategori: bulan ini vs bulan lalu.
    final curByCat = <int, int>{};
    final prevByCat = <int, int>{};
    for (final tx in _txs) {
      if (tx.type == TransactionType.expense && tx.categoryId != null) {
        curByCat[tx.categoryId!] =
            (curByCat[tx.categoryId!] ?? 0) + tx.amount;
      }
    }
    for (final tx in _prevTxs) {
      if (tx.type == TransactionType.expense && tx.categoryId != null) {
        prevByCat[tx.categoryId!] =
            (prevByCat[tx.categoryId!] ?? 0) + tx.amount;
      }
    }
    final sortedCats = curByCat.keys.toList()
      ..sort((a, b) => curByCat[b]!.compareTo(curByCat[a]!));
    // Kategori ini selalu pertama, lalu sisanya desc, maks 6.
    sortedCats.remove(widget.categoryId);
    final compareCats = [
      widget.categoryId,
      ...sortedCats.take(5),
    ];
    final compareLabels = [
      for (final id in compareCats) _categories[id]?.name ?? '—',
    ];
    final compareCur = [
      for (final id in compareCats) curByCat[id] ?? 0,
    ];
    final comparePrev = [
      for (final id in compareCats) prevByCat[id] ?? 0,
    ];

    // Transaksi terbaru (5).
    final recent = _txs
        .where((tx) =>
            tx.categoryId == widget.categoryId &&
            tx.type == TransactionType.expense)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent5 = recent.take(5).toList();

    final prevMonth = DateTime(_month.year, _month.month - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(catName),
        actions: [
          _MonthLabel(month: _month),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Hero: ikon + nama + total + % dari total pengeluaran.
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(catIcon, color: catColor, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(total),
                      style: DuitQuTheme.amountStyle(context, 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.shareOfExpense('$sharePct%'),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Banner perubahan vs bulan lalu + mini chart.
          if (pctChange != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEB5757).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      up
                          ? LucideIcons.arrowUp
                          : LucideIcons.arrowDown,
                      color: const Color(0xFFEB5757),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: up ? t.upLabel : t.downLabel,
                              ),
                              TextSpan(
                                text: ' ${pctChange.abs()}% ',
                                style: const TextStyle(
                                  color: Color(0xFFEB5757),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: t.fromLastMonth),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatRupiah(prevTotal)} → ${formatRupiah(total)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          t.expenseChangeBy(
                            up ? t.upLabel.toLowerCase() : t.downLabel.toLowerCase(),
                            formatRupiah((total - prevTotal).abs()),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    height: 56,
                    child: CustomPaint(
                      painter: MiniBarsPainter(),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Perbandingan 6 bulan terakhir.
          _ChartCard(
            title: t.compareLastMonths(_trendRange),
            rangeLabel: t.monthsLabel(_trendRange),
            onRangeTap: () => _pickTrendRange(context, t),
            child: SizedBox(
              height: 180,
              child: CustomPaint(
                painter: LineChartPainter(
                  values: trendVals,
                  labels: trendLabels,
                  textColor: scheme.onSurfaceVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Perbandingan dengan kategori lain.
          _ChartCard(
            title: t.compareWithOthers,
            rangeLabel: null,
            onRangeTap: null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotLegend(
                  color: scheme.surfaceContainerHighest,
                  label: '${t.shortMonth(prevMonth.month)} ${prevMonth.year}',
                ),
                const SizedBox(width: 12),
                _DotLegend(
                  color: DuitQuTheme.primaryBlue,
                  label: '${t.shortMonth(_month.month)} ${_month.year}',
                ),
              ],
            ),
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                painter: GroupedBarsPainter(
                  first: comparePrev,
                  second: compareCur,
                  labels: compareLabels,
                  textColor: scheme.onSurfaceVariant,
                  firstColor:
                      scheme.surfaceContainerHighest,
                  secondColor: DuitQuTheme.primaryBlue,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Transaksi terbaru: 1 card berisi label + item (ala mockup).
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.recentTransactions,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
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
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t.seeAll),
                              const Icon(LucideIcons.chevronRight, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < recent5.length; i++) ...[
                    _TxRow(
                      tx: recent5[i],
                      onTap: () => _editTransaction(context, recent5[i]),
                    ),
                    if (i < recent5.length - 1)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: const Color(0xFFF7F7F7),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortMonth(int month, AppLocalizations t) {
    const id = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return t.isIndonesian ? id[month - 1] : en[month - 1];
  }

  /// Buka form edit untuk transaksi yang di-tap.
  Future<void> _editTransaction(
      BuildContext context, Transaction tx) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(
        txRepo: widget.txRepo,
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        transferService: widget.transferService,
        defaults: widget.defaults,
        existing: tx,
      ),
    );
  }

  Future<void> _pickTrendRange(BuildContext context, AppLocalizations t) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in [3, 6, 12])
              ListTile(
                title: Text(t.monthsLabel(r)),
                trailing: r == _trendRange
                    ? const Icon(LucideIcons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _setTrendRange(picked);
  }
}

/// Label bulan di AppBar.
class _MonthLabel extends StatelessWidget {
  final DateTime month;

  const _MonthLabel({required this.month});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        formatBulan(month, t),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Kartu chart (duplikat ringan dari insight agar file mandiri).
class _ChartCard extends StatelessWidget {
  final String title;
  final String? rangeLabel;
  final VoidCallback? onRangeTap;
  final Widget? trailing;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.rangeLabel,
    required this.onRangeTap,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (rangeLabel != null)
                  GestureDetector(
                    onTap: onRangeTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rangeLabel!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            LucideIcons.chevronDown,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DotLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _DotLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Baris transaksi: initial merchant + nama + tanggal + nominal.
class _TxRow extends StatelessWidget {
  final Transaction tx;
  final VoidCallback? onTap;

  const _TxRow({required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = tx.merchant ?? tx.note ?? '—';
    // Initial 2 huruf untuk avatar (IB = Isi Bensin).
    final words = title.trim().split(RegExp(r'\s+'));
    final initial = title.trim().isEmpty
        ? '—'
        : words.length > 1
            ? '${words[0][0]}${words[1][0]}'.toUpperCase()
            : words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    // Warna avatar stabil dari nama merchant.
    final avatarColor = _avatarColor(title);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatTanggal(tx.date, AppLocalizations.of(context))} • '
                  '${tx.date.hour.toString().padLeft(2, '0')}:'
                  '${tx.date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(tx.amount),
            style: DuitQuTheme.amountStyle(context, 14),
          ),
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronRight,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            size: 20,
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      child: row,
    );
  }

  /// Warna avatar dari hash nama — stabil per merchant.
  Color _avatarColor(String name) {
    const palette = [
      Color(0xFF2E9BFF),
      Color(0xFF27AE60),
      Color(0xFF9B51E0),
      Color(0xFFF2C94C),
      Color(0xFFEB5757),
      Color(0xFF2D9CDB),
      Color(0xFFF2994A),
      Color(0xFF6FCF97),
    ];
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }
}
