import 'package:flutter/material.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../format.dart';
import '../quick_add_defaults.dart';
import '../theme.dart';
import 'add_transaction_sheet.dart';

/// Layar utama: riwayat transaksi kronologis + tombol catat kilat.
class HomeScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final QuickAddDefaults defaults;

  const HomeScreen({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.defaults,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<void> _init;
  final _categories = <int, Category>{};
  final _accounts = <int, Account>{};

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

  Future<void> _openAdd([Transaction? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(
        txRepo: widget.txRepo,
        accountRepo: widget.accountRepo,
        categoryRepo: widget.categoryRepo,
        defaults: widget.defaults,
        existing: existing,
      ),
    );
    if (saved == true) setState(() {});
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
      appBar: AppBar(title: const Text('DuitQu')),
      body: FutureBuilder(
        future: _init,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<Transaction>>(
            stream: widget.txRepo.watch(const TransactionQuery()),
            builder: (context, snapshot) {
              final txs = snapshot.data ?? [];
              if (txs.isEmpty) {
                return const Center(
                  child: Text(
                    'Belum ada transaksi.\nKetuk + untuk mencatat.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                itemCount: txs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final tx = txs[i];
                  final cat = tx.categoryId == null
                      ? null
                      : _categories[tx.categoryId];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cat == null
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : Color(cat.color).withValues(alpha: 0.15),
                      child: Text(
                        (cat?.name ?? 'T').characters.first.toUpperCase(),
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
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(tx),
                        ),
                      ],
                    ),
                    onTap: () => _openAdd(tx),
                  );
                },
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
