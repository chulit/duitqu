import 'package:flutter/material.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/summary_service.dart';
import '../../domain/services/transfer_service.dart';
import '../category_icons.dart';
import '../l10n/app_localizations.dart';
import '../format.dart';
import '../quick_add_defaults.dart';
import '../theme.dart';
import 'add_transaction_sheet.dart';

/// Beranda: hero total saldo + ringkasan bulan + transaksi dikelompokkan
/// per tanggal. Geser kiri untuk hapus, ketuk untuk ubah.
class HomeScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransferService transferService;
  final QuickAddDefaults defaults;
  final VoidCallback onAdd;

  const HomeScreen({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.transferService,
    required this.defaults,
    required this.onAdd,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _summaryService = SummaryService();

  final _categories = <int, Category>{};
  final _accounts = <int, Account>{};
  int _totalBalance = 0;
  bool _ready = false;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _filterAccountId;
  int? _filterCategoryId;
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepo.list();
    final accs = await widget.accountRepo.list();
    var total = 0;
    for (final a in accs) {
      if (a.id != null) total += await widget.accountRepo.balance(a.id!);
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
      _totalBalance = total;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilter => _filterAccountId != null || _filterCategoryId != null;

  DateTime get _monthStart => DateTime(_month.year, _month.month);
  DateTime get _monthEnd => DateTime(
    _month.year,
    _month.month + 1,
  ).subtract(const Duration(milliseconds: 1));

  List<Transaction> _applyFilters(List<Transaction> txs) {
    var out = txs;
    if (_filterAccountId != null) {
      out = out
          .where(
            (t) =>
                t.accountId == _filterAccountId ||
                t.toAccountId == _filterAccountId,
          )
          .toList();
    }
    if (_filterCategoryId != null) {
      out = out.where((t) => t.categoryId == _filterCategoryId).toList();
    }
    if (_search.isNotEmpty) {
      out = _summaryService.search(out, _search);
    }
    return out;
  }

  Future<void> _openFilter() async {
    int? accountId = _filterAccountId;
    int? categoryId = _filterCategoryId;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).filterTitle,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: accountId,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).accountLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context).allAccounts),
                  ),
                  for (final a in _accounts.values)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setSheetState(() => accountId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: categoryId,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).categoryLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context).allCategories),
                  ),
                  for (final c in _categories.values)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setSheetState(() => categoryId = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterAccountId = null;
                        _filterCategoryId = null;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(AppLocalizations.of(context).reset),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _filterAccountId = accountId;
                        _filterCategoryId = categoryId;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(AppLocalizations.of(context).apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEdit(Transaction tx) async {
    final saved = await showModalBottomSheet<bool>(
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
    if (saved == true) setState(() {});
  }

  Future<void> _confirmDelete(Transaction tx) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteTransactionTitle),
        content: Text('${_titleOf(tx)} • ${formatRupiah(tx.amount)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.txRepo.delete(tx.id!);
    }
  }

  String _titleOf(Transaction tx) {
    if (tx.merchant != null && tx.merchant!.isNotEmpty) return tx.merchant!;
    if (tx.note != null && tx.note!.isNotEmpty) return tx.note!;
    if (tx.type == TransactionType.transfer) {
      return AppLocalizations.of(context).transfer;
    }
    final cat = tx.categoryId == null ? null : _categories[tx.categoryId];
    return cat?.name ?? 'Transaksi';
  }

  String _subtitleOf(Transaction tx) {
    final parts = <String>[];
    if (tx.type == TransactionType.transfer) {
      final from = _accounts[tx.accountId]?.name ?? '?';
      final to = tx.toAccountId == null
          ? '?'
          : _accounts[tx.toAccountId]?.name ?? '?';
      parts.add('$from → $to');
    } else {
      final cat = tx.categoryId == null ? null : _categories[tx.categoryId];
      if (cat != null) parts.add(cat.name);
      final acc = _accounts[tx.accountId]?.name;
      if (acc != null) parts.add(acc);
    }
    if (tx.items.isNotEmpty) parts.add('${tx.items.length} item');
    return parts.join(' • ');
  }

  Color _amountColor(BuildContext context, Transaction tx) {
    switch (tx.type) {
      case TransactionType.income:
        return DuitQuTheme.incomeColor(context);
      case TransactionType.expense:
        return DuitQuTheme.expenseColor(context);
      case TransactionType.transfer:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _amountText(Transaction tx) {
    final sign = tx.type == TransactionType.income
        ? '+'
        : tx.type == TransactionType.expense
        ? '−'
        : '';
    return '$sign${formatRupiah(tx.amount)}';
  }

  /// Label tanggal grup: Hari ini / Kemarin / 12 Okt 2026.
  String _dayLabel(DateTime date) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return t.today;
    if (d == today.subtract(const Duration(days: 1))) return t.yesterday;
    return '${d.day} ${t.shortMonth(d.month)} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _search = '';
                _searchCtrl.clear();
              }
            }),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: _openFilter,
              ),
              if (_hasFilter)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Transaction>>(
              stream: widget.txRepo.watch(
                TransactionQuery(dateFrom: _monthStart, dateTo: _monthEnd),
              ),
              builder: (context, snapshot) {
                final monthTxs = snapshot.data ?? [];
                final summary = _summaryService.summarize(monthTxs);
                final txs = _applyFilters(monthTxs);
                return RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: _BalanceHero(
                            total: _totalBalance,
                            income: summary.income,
                            expense: summary.expense,
                            month: _month,
                            onPrev: () => setState(() {
                              _month = DateTime(_month.year, _month.month - 1);
                            }),
                            onNext: () => setState(() {
                              _month = DateTime(_month.year, _month.month + 1);
                            }),
                          ),
                        ),
                      ),
                      if (_showSearch)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: t.searchHint,
                                prefixIcon: const Icon(Icons.search_rounded),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() => _search = v),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                t.recentTransactions,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (_hasFilter || _search.isNotEmpty)
                                Text(
                                  '${txs.length} transaksi ditampilkan',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (txs.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 56,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    monthTxs.isEmpty
                                        ? t.emptyHistory
                                        : t.noTransactionsThisMonth,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        _TransactionSliverList(
                          txs: txs,
                          dayLabel: _dayLabel,
                          titleOf: _titleOf,
                          subtitleOf: _subtitleOf,
                          amountText: _amountText,
                          amountColor: (tx) => _amountColor(context, tx),
                          categories: _categories,
                          onTap: _openEdit,
                          onDelete: _confirmDelete,
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 96)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Kartu hero: total saldo + navigasi bulan + ringkasan masuk/keluar.
class _BalanceHero extends StatelessWidget {
  final int total;
  final int income;
  final int expense;
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _BalanceHero({
    required this.total,
    required this.income,
    required this.expense,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: onPrev,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
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
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              t.totalBalance,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupiah(total),
              style: DuitQuTheme.amountStyle(
                context,
                34,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FlowPill(
                    icon: Icons.arrow_downward_rounded,
                    label: t.income,
                    amount: income,
                    color: DuitQuTheme.incomeColor(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FlowPill(
                    icon: Icons.arrow_upward_rounded,
                    label: t.expense,
                    amount: expense,
                    color: DuitQuTheme.expenseColor(context),
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

class _FlowPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int amount;
  final Color color;

  const _FlowPill({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  formatRupiah(amount),
                  style: DuitQuTheme.amountStyle(context, 14, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Daftar transaksi dikelompokkan per tanggal, dengan geser-untuk-hapus.
class _TransactionSliverList extends StatelessWidget {
  final List<Transaction> txs;
  final String Function(DateTime) dayLabel;
  final String Function(Transaction) titleOf;
  final String Function(Transaction) subtitleOf;
  final String Function(Transaction) amountText;
  final Color Function(Transaction) amountColor;
  final Map<int, Category> categories;
  final void Function(Transaction) onTap;
  final Future<void> Function(Transaction) onDelete;

  const _TransactionSliverList({
    required this.txs,
    required this.dayLabel,
    required this.titleOf,
    required this.subtitleOf,
    required this.amountText,
    required this.amountColor,
    required this.categories,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <String, List<Transaction>>{};
    for (final tx in txs) {
      final key =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(tx);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Hitung offset: tiap grup = 1 header + n item.
          var offset = 0;
          for (final k in keys) {
            final items = groups[k]!;
            if (index == offset) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  dayLabel(items.first.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            offset++;
            if (index < offset + items.length) {
              return _row(context, items[index - offset]);
            }
            offset += items.length;
          }
          return null;
        },
        childCount: keys.fold<int>(0, (sum, k) => sum + 1 + groups[k]!.length),
      ),
    );
  }

  Widget _row(BuildContext context, Transaction tx) {
    final scheme = Theme.of(context).colorScheme;
    final cat = tx.categoryId == null ? null : categories[tx.categoryId];
    final catColor = cat == null ? scheme.onSurfaceVariant : Color(cat.color);
    return Dismissible(
      key: ValueKey('tx-${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await onDelete(tx);
        return false; // dialog yang memutuskan; stream me-refresh otomatis
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                tx.type == TransactionType.transfer
                    ? Icons.swap_horiz_rounded
                    : categoryIcon(cat?.icon),
                color: catColor,
              ),
            ),
            title: Text(
              titleOf(tx),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              subtitleOf(tx),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              amountText(tx),
              style: DuitQuTheme.amountStyle(
                context,
                15,
                color: amountColor(tx),
              ),
            ),
            onTap: () => onTap(tx),
          ),
        ),
      ),
    );
  }
}
