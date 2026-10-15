import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup_service.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/summary_service.dart';
import '../../domain/services/transfer_service.dart';
import '../backup_sheet.dart';
import '../format.dart';
import '../quick_add_defaults.dart';
import '../theme.dart';
import 'add_transaction_sheet.dart';

/// Layar utama: riwayat transaksi kronologis + tombol catat kilat.
class HomeScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransferService transferService;
  final BackupService backup;
  final QuickAddDefaults defaults;

  const HomeScreen({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.transferService,
    required this.backup,
    required this.defaults,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _summaryService = SummaryService();

  late final Future<void> _init;
  final _categories = <int, Category>{};
  final _accounts = <int, Account>{};

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _filterAccountId;
  int? _filterCategoryId;
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init = _load();
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepo.list();
    final accs = await widget.accountRepo.list();
    _categories
      ..clear()
      ..addEntries(cats.where((c) => c.id != null).map((c) => MapEntry(c.id!, c)));
    _accounts
      ..clear()
      ..addEntries(accs.where((a) => a.id != null).map((a) => MapEntry(a.id!, a)));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilter =>
      _filterAccountId != null || _filterCategoryId != null;

  Future<void> _openFilter() async {
    int? accountId = _filterAccountId;
    int? categoryId = _filterCategoryId;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filter riwayat',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: accountId,
                decoration: const InputDecoration(
                  labelText: 'Akun',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Semua akun')),
                  for (final a in _accounts.values)
                    DropdownMenuItem(
                        value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setSheetState(() => accountId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: categoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Semua kategori')),
                  for (final c in _categories.values)
                    DropdownMenuItem(
                        value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setSheetState(() => categoryId = v),
              ),
              const SizedBox(height: 16),
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
                    child: const Text('Reset'),
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
                    child: const Text('Terapkan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime get _monthStart => DateTime(_month.year, _month.month);
  DateTime get _monthEnd =>
      DateTime(_month.year, _month.month + 1).subtract(
        const Duration(milliseconds: 1),
      );

  List<Transaction> _applyFilters(List<Transaction> txs) {
    var out = txs;
    if (_filterAccountId != null) {
      out = out
          .where((t) =>
              t.accountId == _filterAccountId ||
              t.toAccountId == _filterAccountId)
          .toList();
    }
    if (_filterCategoryId != null) {
      out =
          out.where((t) => t.categoryId == _filterCategoryId).toList();
    }
    if (_search.isNotEmpty) {
      out = _summaryService.search(out, _search);
    }
    return out;
  }

  Future<void> _openAdd([Transaction? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(
        txRepo: widget.txRepo,
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        transferService: widget.transferService,
        defaults: widget.defaults,
        existing: existing,
      ),
    );
    if (saved == true) setState(() {});
  }

  Future<void> _openBackup() async {
    await showModalBottomSheet(
      context: context,
      builder: (_) => BackupSheet(
        onExport: _exportBackup,
        onImport: _importBackup,
      ),
    );
  }

  Future<void> _exportBackup() async {
    try {
      final csv = await widget.backup.exportCsv();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().split('T').first;
      final file = File('${dir.path}/duitqu-backup-$stamp.csv');
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Backup DuitQu'));
    } catch (e) {
      if (mounted) _showBackupError('Gagal mengekspor: $e');
    }
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked.isEmpty) return; // pengguna batal
    final path = picked.single.path;
    if (path == null) return;
    try {
      final csv = await File(path).readAsString();
      final report = await widget.backup.importCsv(csv);
      setState(() {
        _init = _load();
      });
      if (mounted) _showImportReport(report);
    } on BackupFormatException catch (e) {
      if (mounted) _showBackupError(e.message);
    } catch (e) {
      if (mounted) _showBackupError('Gagal mengimpor: $e');
    }
  }

  void _showBackupError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup gagal'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showImportReport(ImportReport report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Impor selesai'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Berhasil diimpor: ${report.accounts} akun, '
                '${report.categories} kategori, '
                '${report.transactions} transaksi, '
                '${report.items} item.',
              ),
              if (report.skipped.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '${report.skipped.length} baris dilewati:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...report.skipped.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Baris ${s.row}: ${s.reason}'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Transaction tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text(
          '${_titleOf(tx)} • ${formatRupiah(tx.amount)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
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
    if (tx.type == TransactionType.transfer) return 'Transfer';
    final cat = tx.categoryId == null ? null : _categories[tx.categoryId];
    return cat?.name ?? 'Transaksi';
  }

  String _subtitleOf(Transaction tx) {
    final parts = <String>[];
    if (tx.type == TransactionType.transfer) {
      final from = _accounts[tx.accountId]?.name ?? '?';
      final to =
          tx.toAccountId == null ? '?' : _accounts[tx.toAccountId]?.name ?? '?';
      parts.add('$from → $to');
    } else {
      final cat = tx.categoryId == null ? null : _categories[tx.categoryId];
      if (cat != null) parts.add(cat.name);
      final acc = _accounts[tx.accountId]?.name;
      if (acc != null) parts.add(acc);
    }
    if (tx.items.isNotEmpty) {
      parts.add('${tx.items.length} item');
    }
    parts.add(formatTanggal(tx.date));
    return parts.join(' • ');
  }

  Color _amountColor(BuildContext context, Transaction tx) {
    switch (tx.type) {
      case TransactionType.income:
        return DuitQuTheme.emerald;
      case TransactionType.expense:
        return DuitQuTheme.terracotta;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DuitQu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _search = '';
                _searchCtrl.clear();
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Backup',
            onPressed: _openBackup,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilter,
              ),
              if (_hasFilter)
                Positioned(
                  right: 8,
                  top: 8,
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
        ],
      ),
      body: FutureBuilder(
        future: _init,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<Transaction>>(
            stream: widget.txRepo.watch(TransactionQuery(
              dateFrom: _monthStart,
              dateTo: _monthEnd,
            )),
            builder: (context, snapshot) {
              final monthTxs = snapshot.data ?? [];
              final summary = _summaryService.summarize(monthTxs);
              final txs = _applyFilters(monthTxs);
              return Column(
                children: [
                  _SummaryCard(
                    month: _month,
                    income: summary.income,
                    expense: summary.expense,
                    net: summary.net,
                    onPrev: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                    }),
                    onNext: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                    }),
                  ),
                  if (_showSearch)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Cari catatan, merchant, barang…',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            setState(() => _search = v),
                      ),
                    ),
                  if (_hasFilter || _search.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${txs.length} transaksi ditampilkan',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                      ),
                    ),
                  Expanded(
                    child: txs.isEmpty
                        ? Center(
                            child: Text(
                              monthTxs.isEmpty
                                  ? 'Belum ada transaksi.\nKetuk + untuk mencatat.'
                                  : 'Tidak ada yang cocok dengan filter.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: txs.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final tx = txs[i];
                              final cat = tx.categoryId == null
                                  ? null
                                  : _categories[tx.categoryId];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cat == null
                                      ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                      : Color(cat.color)
                                          .withValues(alpha: 0.15),
                                  child: Text(
                                    (cat?.name ?? 'T')
                                        .characters
                                        .first
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: cat == null
                                          ? null
                                          : Color(cat.color),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(_titleOf(tx)),
                                subtitle: Text(_subtitleOf(tx)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _amountText(tx),
                                      style: DuitQuTheme.amountStyle(
                                        context,
                                        15,
                                        color: _amountColor(context, tx),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline),
                                      onPressed: () =>
                                          _confirmDelete(tx),
                                    ),
                                  ],
                                ),
                                onTap: () => _openAdd(tx),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Kartu ringkasan bulan: pemasukan, pengeluaran, selisih.
class _SummaryCard extends StatelessWidget {
  final DateTime month;
  final int income;
  final int expense;
  final int net;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _SummaryCard({
    required this.month,
    required this.income,
    required this.expense,
    required this.net,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrev,
                ),
                Text(
                  formatBulan(month),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  label: 'Masuk',
                  amount: income,
                  color: DuitQuTheme.emerald,
                ),
                _SummaryItem(
                  label: 'Keluar',
                  amount: expense,
                  color: DuitQuTheme.terracotta,
                ),
                _SummaryItem(
                  label: 'Selisih',
                  amount: net,
                  color: net >= 0
                      ? DuitQuTheme.emerald
                      : DuitQuTheme.terracotta,
                  signed: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final bool signed;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = signed && amount > 0
        ? '+${formatRupiah(amount)}'
        : formatRupiah(amount);
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          text,
          style: DuitQuTheme.amountStyle(context, 16, color: color),
        ),
      ],
    );
  }
}
