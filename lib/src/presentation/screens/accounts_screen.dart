import 'package:flutter/material.dart';

import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../category_icons.dart';
import '../l10n/app_localizations.dart';
import '../format.dart';
import '../widgets/mascot_image.dart';
import 'account_detail_screen.dart';
import 'account_form_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Daftar akun keuangan ala mockup: header + total saldo + list + tambah.
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
  bool _hideBalance = false;
  List<Account> _accounts = [];
  Map<int, int> _balances = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await widget.accountRepo.list();
    final balances = <int, int>{};
    for (final a in accounts) {
      if (a.id != null) {
        balances[a.id!] = await widget.accountRepo.balance(a.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _balances = balances;
      _loading = false;
    });
  }

  int get _total => _balances.values.fold(0, (a, b) => a + b);

  String _balanceText(int v) => _hideBalance ? 'Rp ••••••' : formatRupiah(v);

  Future<void> _openForm(Account? existing) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountFormScreen(
          accountRepo: widget.accountRepo,
          existing: existing,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetail(Account account) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountDetailScreen(
          account: account,
          accountRepo: widget.accountRepo,
        ),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // Header: back + title + subtitle + tambah.
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.arrowLeft),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.accountsTitle,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.accountsSubtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.plus),
                          onPressed: () => _openForm(null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Kartu total saldo.
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t.totalBalance,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _hideBalance = !_hideBalance,
                                      ),
                                      child: Icon(
                                        _hideBalance
                                            ? LucideIcons.eyeOff
                                            : LucideIcons.eye,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _balanceText(_total),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const MascotImage.coin(size: 84),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // List akun.
                    ..._accounts.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AccountRow(
                          account: a,
                          balance: _balances[a.id] ?? 0,
                          hideBalance: _hideBalance,
                          onTap: () => _openDetail(a),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Tombol tambah akun.
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _openForm(null),
                        icon: const Icon(LucideIcons.plus, size: 20),
                        label: Text(
                          t.addAccountBtn,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Satu baris akun: ikon warna + nama + jenis + saldo + "...".
class _AccountRow extends StatelessWidget {
  final Account account;
  final int balance;
  final bool hideBalance;
  final VoidCallback onTap;

  const _AccountRow({
    required this.account,
    required this.balance,
    required this.hideBalance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color = Color(account.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                accountIcon(account.type),
                color: Colors.white,
                size: 24,
              ),
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
                    accountTypeLabel(account.type, t),
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hideBalance ? 'Rp ••••••' : formatRupiah(balance),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                LucideIcons.ellipsis,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Label jenis akun mengikuti bahasa.
String accountTypeLabel(AccountType type, AppLocalizations t) {
  switch (type) {
    case AccountType.bank:
      return t.accountTypeBank;
    case AccountType.ewallet:
      return t.accountTypeEwallet;
    case AccountType.creditCard:
      return t.accountTypeCreditCard;
    case AccountType.cash:
      return t.accountTypeCash;
    case AccountType.other:
      return t.accountTypeOther;
  }
}

/// Metadata jenis akun untuk form: ikon + warna default.
class AccountTypeMeta {
  final AccountType type;
  final IconData icon;
  final int defaultColor;

  const AccountTypeMeta(this.type, this.icon, this.defaultColor);
}

/// 4 jenis akun ala mockup (other disembunyikan, tetap didukung).
List<AccountTypeMeta> accountTypeOptions(AppLocalizations t) => const [
      AccountTypeMeta(AccountType.bank, LucideIcons.landmark, 0xFF2E9BFF),
      AccountTypeMeta(AccountType.ewallet, LucideIcons.wallet, 0xFF14B8A6),
      AccountTypeMeta(
          AccountType.creditCard, LucideIcons.creditCard, 0xFF9B51E0),
      AccountTypeMeta(AccountType.cash, LucideIcons.banknote, 0xFF27AE60),
    ];

/// Pilihan warna ala mockup.
List<ColorOption> accountColorOptions(AppLocalizations t) => [
      ColorOption(0xFF2E9BFF, t.colorBlue),
      ColorOption(0xFF27AE60, t.colorGreen),
      ColorOption(0xFF9B51E0, t.colorPurple),
      ColorOption(0xFFEB5757, t.colorRed),
      ColorOption(0xFFF2994A, t.colorOrange),
      ColorOption(0xFFBDBDBD, t.colorGray),
    ];

class ColorOption {
  final int value;
  final String label;
  const ColorOption(this.value, this.label);
}

/// Daftar bank umum Indonesia untuk dropdown.
const List<String> commonBanks = [
  'BCA (Bank Central Asia)',
  'BRI (Bank Rakyat Indonesia)',
  'Mandiri',
  'BNI (Bank Negara Indonesia)',
  'CIMB Niaga',
  'Danamon',
  'BTN (Bank Tabungan Negara)',
  'Permata',
  'OCBC',
  'Maybank',
];
