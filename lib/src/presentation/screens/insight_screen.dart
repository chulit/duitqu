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
import '../widgets/chart_painters.dart';
import '../widgets/donut_chart.dart';
import '../widgets/mascot_image.dart';
import 'category_detail_screen.dart';

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

enum _Tab { ringkasan, kategori, tren }

class _InsightScreenState extends State<InsightScreen> {
  static const _summaryService = SummaryService();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _Tab _tab = _Tab.ringkasan;
  // Mode tampilan tab Kategori: true = Jumlah (nominal), false = Persentase.
  bool _kategoriByAmount = true;
  final _categories = <int, Category>{};
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

  void _selectMonth(DateTime month) {
    setState(() {
      _month = DateTime(month.year, month.month);
      _txStream = _makeStream();
    });
    _loadPrevMonth();
    _loadTrend();
  }

  Future<void> _openMonthPicker(BuildContext context) async {
    // Cari tahun transaksi pertama untuk batas mundur.
    final all = await widget.txRepo.list(const TransactionQuery());
    final minYear = all.isEmpty
        ? DateTime.now().year
        : all
            .map((tx) => tx.date.year)
            .reduce((a, b) => a < b ? a : b);
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (ctx) => _MonthPickerSheet(
        initial: _month,
        now: DateTime.now(),
        minYear: minYear,
      ),
    );
    if (picked != null) _selectMonth(picked);
  }

  void _setTab(_Tab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  void _setTrendRange(int range) {
    if (_trendRange == range) return;
    setState(() => _trendRange = range);
    _loadTrend();
  }

  // Total per bulan untuk N bulan terakhir (tren).
  List<int> _trendIncome = [];
  List<int> _trendExpense = [];
  // Total pengeluaran per hari untuk bulan terpilih.
  List<int> _dailyExpense = [];
  // Rentang tren: 3 / 6 / 12 bulan.
  int _trendRange = 6;

  /// Muat tren pemasukan & pengeluaran untuk [_trendRange] bulan terakhir,
  /// plus pengeluaran harian bulan terpilih.
  Future<void> _loadTrend() async {
    final range = _trendRange;
    final endMonth = DateTime(_month.year, _month.month);
    final startMonth = DateTime(_month.year, _month.month - range + 1);
    final txs = await widget.txRepo.list(
      TransactionQuery(
        dateFrom: DateTime(startMonth.year, startMonth.month),
        dateTo: DateTime(endMonth.year, endMonth.month + 1).subtract(
          const Duration(milliseconds: 1),
        ),
      ),
    );
    final income = List<int>.filled(range, 0);
    final expense = List<int>.filled(range, 0);
    for (final tx in txs) {
      final idx = (tx.date.year - startMonth.year) * 12 +
          (tx.date.month - startMonth.month);
      if (idx < 0 || idx >= range) continue;
      if (tx.type == TransactionType.income) {
        income[idx] += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        expense[idx] += tx.amount;
      }
    }
    // Harian: agregasi pengeluaran per tanggal di bulan terpilih.
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;
    final daily = List<int>.filled(daysInMonth, 0);
    for (final tx in txs) {
      if (tx.type != TransactionType.expense) continue;
      if (tx.date.year == _month.year && tx.date.month == _month.month) {
        daily[tx.date.day - 1] += tx.amount;
      }
    }
    if (!mounted) return;
    setState(() {
      _trendIncome = income;
      _trendExpense = expense;
      _dailyExpense = daily;
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
        builder: (_) => CategoryDetailScreen(
          categoryId: categoryId,
          month: _month,
          txRepo: widget.txRepo,
          categoryRepo: widget.categoryRepo,
          accountRepo: widget.accountRepo,
          transferService: widget.transferService,
          defaults: widget.defaults,
        ),
      ),
    );
  }

  /// Warna badge %: expense naik=merah (boros), turun=hijau (hemat);
  /// income kebalikannya.
  Color _pctColor(int? pct, bool isExpense, ColorScheme scheme) {
    if (pct == null || pct == 0) return scheme.onSurfaceVariant;
    final up = pct > 0;
    final good = isExpense ? !up : up;
    return good ? const Color(0xFF27AE60) : const Color(0xFFEB5757);
  }

  /// Tab Ringkasan ala mockup: kartu insight + 2 mini card +
  /// donut pengeluaran + kartu tips.
  List<Widget> _buildRingkasan({
    required BuildContext context,
    required AppLocalizations t,
    required ColorScheme scheme,
    required List<MapEntry<int, int>> expenseEntries,
    required int expenseTotal,
    required int incomeTotal,
    required int? expensePct,
    required int? incomePct,
    required String? topExpenseCat,
    required int? topExpenseCatId,
  }) {
    return [
      // Kartu insight maskot (tanpa chevron, sesuai keputusan).
      // Dua mini card: Pemasukan | Pengeluaran.
      Row(
        children: [
          Expanded(
            child: _MiniTotalCard(
              label: t.incomeTab,
              total: incomeTotal,
              pct: incomePct,
              isExpense: false,
              pctColor: _pctColor(incomePct, false, scheme),
              onTap: () => _setTab(_Tab.kategori),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MiniTotalCard(
              label: t.expenseTab,
              total: expenseTotal,
              pct: expensePct,
              isExpense: true,
              pctColor: _pctColor(expensePct, true, scheme),
              onTap: () => _setTab(_Tab.kategori),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (expenseEntries.isEmpty)
        _EmptyInsight(t: t)
      else ...[
        // Donut pengeluaran (tanpa "Lihat Semua").
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.expensePerCategory,
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
                              for (final e in expenseEntries)
                                e.value.toDouble(),
                            ],
                            colors: [
                              for (var i = 0;
                                  i < expenseEntries.length;
                                  i++)
                                _brightColor(i),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatRupiah(expenseTotal),
                                style: DuitQuTheme.amountStyle(
                                  context,
                                  16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.totalLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
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
                              i < expenseEntries.length;
                              i++)
                            _LegendDot(
                              name: _categories[expenseEntries[i].key]
                                      ?.name ??
                                  '—',
                              total: expenseTotal,
                              amount: expenseEntries[i].value,
                              color: _brightColor(i),
                              onTap: () => _openCategory(
                                  context, expenseEntries[i].key),
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
        // Kartu tips: tap -> detail kategori terbesar.
        _TipCard(
          categoryName: topExpenseCat,
          onTap: topExpenseCatId == null
              ? () {}
              : () => _openCategory(context, topExpenseCatId),
        ),
      ],
    ];
  }

  /// Tab Kategori ala mockup: judul + toggle Jumlah/Persentase +
  /// daftar lengkap + kartu tips.
  Widget _buildKategori({
    required BuildContext context,
    required AppLocalizations t,
    required ColorScheme scheme,
    required List<MapEntry<int, int>> entries,
    required int total,
    required String? topCategoryName,
    required int? topCategoryId,
  }) {


    if (entries.isEmpty) return _EmptyInsight(t: t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.expensePerCategory,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _JumlahToggle(
              byAmount: _kategoriByAmount,
              onChanged: (v) => setState(() => _kategoriByAmount = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _KategoriRow(
                    name: _categories[entries[i].key]?.name ?? '—',
                    icon: categoryIcon(
                      _categories[entries[i].key]?.icon,
                    ),
                    amount: entries[i].value,
                    total: total,
                    color: _brightColor(i),
                    byAmount: _kategoriByAmount,
                    onTap: () => _openCategory(context, entries[i].key),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _TipCard(
          categoryName: topCategoryName,
          onTap: topCategoryId == null
              ? () {}
              : () => _openCategory(context, topCategoryId),
        ),
      ],
    );
  }

  /// Tab Tren ala mockup: 3 kartu chart.
  List<Widget> _buildTren({
    required BuildContext context,
    required AppLocalizations t,
    required ColorScheme scheme,
  }) {
    // Label bulan untuk N bulan terakhir (Mei..Okt).
    final monthLabels = <String>[];
    for (var i = _trendRange - 1; i >= 0; i--) {
      final d = DateTime(_month.year, _month.month - i);
      monthLabels.add(_shortMonth(d.month, t));
    }
    return [
      // 1. Grouped bar: Pemasukan vs Pengeluaran.
      _ChartCard(
        title: t.trendIncomeVsExpense,
        rangeLabel: t.monthsLabel(_trendRange),
        onRangeTap: () => _pickTrendRange(context, t),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: GroupedBarsPainter(
                  first: _trendIncome,
                  second: _trendExpense,
                  labels: monthLabels,
                  textColor: scheme.onSurfaceVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DotLegend(
                  color: const Color(0xFF27AE60),
                  label: t.incomeTab,
                ),
                const SizedBox(width: 16),
                _DotLegend(
                  color: const Color(0xFFEB5757),
                  label: t.expenseTab,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // 2. Line chart: Tren Pengeluaran.
      _ChartCard(
        title: t.trendExpenseTitle,
        rangeLabel: t.monthsLabel(_trendRange),
        onRangeTap: () => _pickTrendRange(context, t),
        child: SizedBox(
          height: 180,
          child: CustomPaint(
            painter: LineChartPainter(
              values: _trendExpense,
              labels: monthLabels,
              textColor: scheme.onSurfaceVariant,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // 3. Daily bars: Pengeluaran per Hari.
      _ChartCard(
        title: t.dailyExpenseTitle,
        rangeLabel: formatBulan(_month, t),
        onRangeTap: null,
        child: SizedBox(
          height: 160,
          child: CustomPaint(
            painter: DailyBarsPainter(
              values: _dailyExpense,
              textColor: scheme.onSurfaceVariant,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ];
  }

  /// Nama bulan singkat: Jan, Feb, ... (ID) / Jan, Feb, ... (EN).
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

  /// Pilih rentang tren: 3 / 6 / 12 bulan.
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
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _setTrendRange(picked);
  }


  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<Transaction>>(
              stream: _txStream,
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                final expenseByCat =
                    _summaryService.expenseByCategory(txs);
                final incomeByCat =
                    _byCategory(txs, TransactionType.income);
                final prevExpenseByCat =
                    _summaryService.expenseByCategory(_prevTxs);
                final prevIncomeByCat =
                    _byCategory(_prevTxs, TransactionType.income);

                final expenseEntries = _sortedEntries(expenseByCat);
                final expenseTotal =
                    expenseEntries.fold<int>(0, (a, e) => a + e.value);
                final incomeTotal =
                    incomeByCat.values.fold<int>(0, (a, v) => a + v);
                final prevExpenseTotal =
                    prevExpenseByCat.values.fold<int>(0, (a, v) => a + v);
                final prevIncomeTotal =
                    prevIncomeByCat.values.fold<int>(0, (a, v) => a + v);
                final expensePct =
                    _pctChange(expenseTotal, prevExpenseTotal);
                final incomePct =
                    _pctChange(incomeTotal, prevIncomeTotal);
                // Kategori pengeluaran terbesar (untuk kartu insight).
                final topExpenseCat = expenseEntries.isEmpty
                    ? null
                    : _categories[expenseEntries.first.key]?.name;
                final topExpenseCatId = expenseEntries.isEmpty
                    ? null
                    : expenseEntries.first.key;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  children: [
                    // Header ala mockup: judul + subtitle + pilih bulan.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.insightTitle,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.insightSubtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _MonthPicker(
                          month: _month,
                          onTap: () => _openMonthPicker(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Kartu maskot selalu di atas pill (ala mockup).
                    _InsightMascotCard(
                      pct: expensePct,
                      topCategory: topExpenseCat,
                    ),
                    const SizedBox(height: 16),
                    _InsightTabBar(
                      tab: _tab,
                      onChanged: _setTab,
                    ),
                    const SizedBox(height: 16),
                    if (_tab == _Tab.ringkasan)
                      ..._buildRingkasan(
                        context: context,
                        t: t,
                        scheme: scheme,
                        expenseEntries: expenseEntries,
                        expenseTotal: expenseTotal,
                        incomeTotal: incomeTotal,
                        expensePct: expensePct,
                        incomePct: incomePct,
                        topExpenseCat: topExpenseCat,
                        topExpenseCatId: topExpenseCatId,
                      ),
                    if (_tab == _Tab.kategori)
                      _buildKategori(
                        context: context,
                        t: t,
                        scheme: scheme,
                        entries: expenseEntries,
                        total: expenseTotal,
                        topCategoryName: topExpenseCat,
                        topCategoryId: topExpenseCatId,
                      ),
                    if (_tab == _Tab.tren)
                      ..._buildTren(
                        context: context,
                        t: t,
                        scheme: scheme,
                      ),
                  ],
                );
              },
            ),
      ),
    );
  }

  /// Warna cerah ala mockup, dipetakan menurut urutan legend (desc).
  Color _brightColor(int index) =>
      _brightPalette[index % _brightPalette.length];

  static const _brightPalette = [
    Color(0xFF3B82F6), // biru medium
    Color(0xFF22C55E), // hijau medium
    Color(0xFFA855F7), // ungu medium
    Color(0xFFEAB308), // kuning golden
    Color(0xFFF87171), // merah coral medium
    Color(0xFFCBD5E1), // abu kebiruan (Lainnya)
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

}

/// Pilih bulan ala mockup: "<  Juli 2025  >".
/// Pilih bulan ala mockup: pill "Oktober 2026" dengan chevron.
class _MonthPicker extends StatelessWidget {
  final DateTime month;
  final VoidCallback onTap;

  const _MonthPicker({
    required this.month,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          formatBulan(month, t),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet pilih bulan ala mockup: tahun + grid 3x4 + tombol bulan ini.
class _MonthPickerSheet extends StatefulWidget {
  final DateTime initial;
  final DateTime now;
  final int minYear;

  const _MonthPickerSheet({
    required this.initial,
    required this.now,
    required this.minYear,
  });

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  static const _monthsId = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final months = t.isIndonesian ? _monthsId : _monthsEn;
    final isCurrentYear = _year == widget.now.year;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Navigasi tahun.
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _year <= widget.minYear
                      ? null
                      : () => setState(() => _year--),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _year >= widget.now.year
                      ? null
                      : () => setState(() => _year++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Grid bulan 3x4.
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: 12,
              itemBuilder: (ctx, i) {
                final selected = _year == widget.initial.year &&
                    i + 1 == widget.initial.month;
                // Bulan depan (masa depan) tidak bisa dipilih.
                final isFuture = _year > widget.now.year ||
                    (_year == widget.now.year &&
                        i + 1 > widget.now.month);
                return InkWell(
                  onTap: isFuture
                      ? null
                      : () => Navigator.pop(
                            ctx, DateTime(_year, i + 1)),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? DuitQuTheme.primaryBlue
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      months[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : isFuture
                                ? scheme.onSurfaceVariant
                                    .withValues(alpha: 0.4)
                                : scheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Tombol kembali ke bulan ini.
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isCurrentYear &&
                        widget.initial.month == widget.now.month
                    ? null
                    : () => Navigator.pop(
                          context,
                          DateTime(widget.now.year, widget.now.month),
                        ),
                child: Text(t.backToThisMonth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab bar 3 pill ala mockup: Ringkasan | Kategori | Tren.
class _InsightTabBar extends StatelessWidget {
  final _Tab tab;
  final ValueChanged<_Tab> onChanged;

  const _InsightTabBar({
    required this.tab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget pill(_Tab value, String label) {
      final active = tab == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? DuitQuTheme.primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
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
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          pill(_Tab.ringkasan, t.tabRingkasan),
          pill(_Tab.kategori, t.tabKategori),
          pill(_Tab.tren, t.tabTren),
        ],
      ),
    );
  }
}

/// Kartu insight maskot ala mockup: "Pengeluaranmu naik 15%".
/// Tanpa chevron (sesuai keputusan).
class _InsightMascotCard extends StatelessWidget {
  final int? pct;
  final String? topCategory;

  const _InsightMascotCard({
    required this.pct,
    required this.topCategory,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pctStr = pct == null ? '—' : '${pct!.abs()}%';
    final naik = (pct ?? 0) >= 0;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const MascotImage.chart(size: 96),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.insightExpenseChange(pctStr, naik),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.insightExpenseDetail(topCategory ?? '—'),
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
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

/// Mini card total ala mockup: label + nominal + % vs bulan lalu.
/// Panah selalu ke atas bila naik (sesuai keputusan).
class _MiniTotalCard extends StatelessWidget {
  final String label;
  final int total;
  final int? pct;
  final bool isExpense;
  final Color pctColor;

  final VoidCallback? onTap;

  const _MiniTotalCard({
    required this.label,
    required this.total,
    required this.pct,
    required this.isExpense,
    required this.pctColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final up = (pct ?? 0) >= 0;
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    up
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 20,
                    color: pctColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatRupiah(total),
              style: DuitQuTheme.amountStyle(context, 20),
            ),
            if (pct != null) ...[
              const SizedBox(height: 6),
              Text(
                t.pctFromLastMonth('${pct!.abs()}%', up),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pctColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }
}

/// Legend donut ala mockup: dot warna + nama + persen (tanpa nominal).
class _LegendDot extends StatelessWidget {
  final String name;
  final int amount;
  final int total;
  final Color color;

  final VoidCallback? onTap;

  const _LegendDot({
    required this.name,
    required this.amount,
    required this.total,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0 : (amount / total * 100).round();
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

/// Kartu tips ala mockup: tap -> pindah ke tab Kategori.
class _TipCard extends StatelessWidget {
  final String? categoryName;
  final VoidCallback onTap;

  const _TipCard({
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F2FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const MascotImage.idea(size: 84),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: t.tipBiggestCategoryPrefix),
                          TextSpan(
                            text: '\n${categoryName ?? '—'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: DuitQuTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.tipSetBudget,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris kategori tab Kategori: ikon + nama + nominal + progress + persen.
/// Tap -> daftar transaksi.
class _KategoriRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final int amount;
  final int total;
  final Color color;
  final bool byAmount;
  final VoidCallback onTap;

  const _KategoriRow({
    required this.name,
    required this.icon,
    required this.amount,
    required this.total,
    required this.color,
    required this.byAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
    final pct = (fraction * 100).round();
    // Mode Jumlah: nominal tegas, persen redup. Mode Persentase: sebaliknya.
    final primary = byAmount ? formatRupiah(amount) : '$pct%';
    final secondary = byAmount ? '$pct%' : formatRupiah(amount);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
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
                      backgroundColor: scheme.surfaceContainerHighest,
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
                  primary,
                  style: DuitQuTheme.amountStyle(
                    context,
                    14,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle kecil ala mockup: Jumlah | Persentase.
class _JumlahToggle extends StatelessWidget {
  final bool byAmount;
  final ValueChanged<bool> onChanged;

  const _JumlahToggle({
    required this.byAmount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget opt(bool value, String label) {
      final active = byAmount == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? DuitQuTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          opt(true, t.kategoriJumlahLabel),
          opt(false, t.percentLabel),
        ],
      ),
    );
  }
}


/// Kartu chart ala mockup: judul + dropdown range + konten.
class _ChartCard extends StatelessWidget {
  final String title;
  final String rangeLabel;
  final VoidCallback? onRangeTap;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.rangeLabel,
    required this.onRangeTap,
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
                if (onRangeTap != null)
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
                            rangeLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      rangeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

/// Legend dot kecil: "● Pemasukan".
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
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Format singkat untuk sumbu Y: 6jt, 300rb.
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
