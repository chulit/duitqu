import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../category_icons.dart';
import '../l10n/app_localizations.dart';
import '../format.dart';
import '../theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Daftar akun: kartu saldo + tambah/ubah/hapus.
class AccountsScreen extends StatefulWidget {
  final AccountRepository accountRepo;
  final TransactionRepository txRepo;

  const AccountsScreen({
    super.key,
    required this.accountRepo,
    required this.txRepo,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.navAccounts)),
      body: FutureBuilder<List<Account>>(
        future: widget.accountRepo.list(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) {
            return Center(child: Text(t.addAccount));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _AccountCard(
                account: accounts[i],
                accountRepo: widget.accountRepo,
                onChanged: () => setState(() {}),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(null).then((_) => setState(() {})),
        icon: const Icon(LucideIcons.plus),
        label: Text(AppLocalizations.of(context).addAccount),
      ),
    );
  }

  Future<void> _openEditor(Account? existing) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _AccountEditor(accountRepo: widget.accountRepo, existing: existing),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final AccountRepository accountRepo;
  final VoidCallback onChanged;

  const _AccountCard({
    required this.account,
    required this.accountRepo,
    required this.onChanged,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteAccountTitle),
        content: Text(t.deleteAccountMessage(account.name)),
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
    if (ok != true || !context.mounted) return;
    try {
      await accountRepo.delete(account.id!);
      onChanged();
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(account.color);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(DuitQuTheme.radius),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) =>
              _AccountEditor(accountRepo: accountRepo, existing: account),
        ).then((_) => onChanged()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(accountIcon(account.type), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _typeLabel(context, account.type),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FutureBuilder<int>(
                future: account.id == null
                    ? Future.value(0)
                    : accountRepo.balance(account.id!),
                builder: (context, snapshot) {
                  final balance = snapshot.data ?? 0;
                  return Text(
                    formatRupiah(balance),
                    style: DuitQuTheme.amountStyle(
                      context,
                      17,
                      color: balance >= 0
                          ? DuitQuTheme.incomeColor(context)
                          : DuitQuTheme.expenseColor(context),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2),
                color: scheme.onSurfaceVariant,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(BuildContext context, AccountType type) {
    // Label jenis akun mengikuti bahasa perangkat.
    const id = {
      AccountType.bank: 'Bank',
      AccountType.cash: 'Tunai',
      AccountType.ewallet: 'E-wallet',
      AccountType.other: 'Lainnya',
    };
    const en = {
      AccountType.bank: 'Bank',
      AccountType.cash: 'Cash',
      AccountType.ewallet: 'E-wallet',
      AccountType.other: 'Other',
    };
    final isId = AppLocalizations.of(context).locale.languageCode == 'id';
    return (isId ? id : en)[type]!;
  }
}

/// Editor tambah/ubah akun (bottom sheet).
class _AccountEditor extends StatefulWidget {
  final AccountRepository accountRepo;
  final Account? existing;

  const _AccountEditor({required this.accountRepo, this.existing});

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  late AccountType _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _balanceCtrl = TextEditingController(
      text: ex == null ? '' : ex.initialBalance.toString(),
    );
    _type = ex?.type ?? AccountType.bank;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = t.accountName);
      return;
    }
    final balance = int.tryParse(_balanceCtrl.text.trim()) ?? 0;
    final ex = widget.existing;
    await widget.accountRepo.save(
      Account(
        id: ex?.id,
        name: name,
        type: _type,
        initialBalance: balance,
        icon: ex?.icon ?? 'wallet',
        color: ex?.color ?? 0xFF0E7C5B,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? t.addAccount : t.editAccount,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: widget.existing == null,
            decoration: InputDecoration(labelText: t.accountName),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: t.navAccounts),
            items: AccountType.values
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Row(
                      children: [
                        Icon(accountIcon(e), size: 20),
                        const SizedBox(width: 8),
                        Text(e.name),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: t.initialBalance,
              prefixText: 'Rp ',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: Text(t.save)),
        ],
      ),
    );
  }
}
