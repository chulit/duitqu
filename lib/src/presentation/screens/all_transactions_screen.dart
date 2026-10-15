import 'package:flutter/material.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transfer_service.dart';
import '../category_icons.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../quick_add_defaults.dart';
import '../theme.dart';
import 'add_transaction_sheet.dart';

/// Daftar seluruh transaksi (dari "Lihat semua").
class AllTransactionsScreen extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransferService transferService;
  final QuickAddDefaults defaults;

  const AllTransactionsScreen({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.transferService,
    required this.defaults,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final _categories = <int, Category>{};
  final _accounts = <int, Account>{};
  bool _ready = false;
  late final Stream<List<Transaction>> _txStream;

  @override
  void initState() {
    super.initState();
    _txStream = widget.txRepo.watch(const TransactionQuery());
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.categoryRepo.list();
    final accs = await widget.accountRepo.list();
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
      _ready = true;
    });
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.recentTransactions)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Transaction>>(
              stream: _txStream,
              builder: (context, snapshot) {
                final txs = snapshot.data ?? [];
                if (txs.isEmpty) {
                  return Center(
                    child: Text(
                      t.emptyHistory,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: txs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final tx = txs[i];
                    final cat = tx.categoryId == null
                        ? null
                        : _categories[tx.categoryId];
                    final catColor = cat == null
                        ? scheme.onSurfaceVariant
                        : Color(cat.color);
                    final isExpense = tx.type == TransactionType.expense;
                    final isIncome = tx.type == TransactionType.income;
                    return Card(
                      child: ListTile(
                        onTap: () => _openEdit(tx),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
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
                          tx.merchant ??
                              (tx.type == TransactionType.transfer
                                  ? t.transfer
                                  : (cat?.name ?? '—')),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(formatTanggal(tx.date, t)),
                        trailing: Text(
                          '${isExpense
                              ? '−'
                              : isIncome
                              ? '+'
                              : ''}${formatRupiah(tx.amount)}',
                          style: DuitQuTheme.amountStyle(
                            context,
                            15,
                            color: isIncome
                                ? DuitQuTheme.income
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
