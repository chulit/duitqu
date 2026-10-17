import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../category_icons.dart';
import '../l10n/app_localizations.dart';
import 'accounts_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Form tambah/ubah akun ala mockup.
class AccountFormScreen extends StatefulWidget {
  final AccountRepository accountRepo;
  final Account? existing;

  const AccountFormScreen({
    super.key,
    required this.accountRepo,
    this.existing,
  });

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _balanceCtrl;
  late AccountType _type;
  late int _color;
  String? _bankName;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _numberCtrl = TextEditingController(text: ex?.accountNumber ?? '');
    _balanceCtrl = TextEditingController(
      text: ex == null || ex.initialBalance == 0
          ? ''
          : ex.initialBalance.toString(),
    );
    _type = ex?.type ?? AccountType.bank;
    _color = ex?.color ?? _defaultColorFor(_type);
    _bankName = ex?.bankName;
  }

  static int _defaultColorFor(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return 0xFF2E9BFF;
      case AccountType.ewallet:
        return 0xFF14B8A6;
      case AccountType.creditCard:
        return 0xFF9B51E0;
      case AccountType.cash:
        return 0xFF27AE60;
      case AccountType.other:
        return 0xFFBDBDBD;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _selectType(AccountType type) {
    setState(() {
      _type = type;
      _color = _defaultColorFor(type);
      if (type != AccountType.bank) _bankName = null;
    });
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
        color: _color,
        bankName: _type == AccountType.bank ? _bankName : null,
        accountNumber: _numberCtrl.text.trim().isEmpty
            ? null
            : _numberCtrl.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final types = accountTypeOptions(t);
    final colors = accountColorOptions(t);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? t.editAccount : t.addAccountBtn,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Pilih jenis akun.
          Text(
            t.selectAccountType,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: types.length,
            itemBuilder: (context, i) {
              final meta = types[i];
              final selected = meta.type == _type;
              final c = Color(meta.defaultColor);
              return GestureDetector(
                onTap: () => _selectType(meta.type),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? c.withValues(alpha: 0.08)
                        : scheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? const Color(0xFF2E9BFF) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(meta.icon,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        accountTypeLabel(meta.type, t),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? const Color(0xFF2E9BFF)
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Detail akun.
          Text(
            t.accountDetailTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _label(t.accountName),
          _textField(
            controller: _nameCtrl,
            hint: t.accountName,
            onClear: () => _nameCtrl.clear(),
          ),
          const SizedBox(height: 12),
          if (_type == AccountType.bank) ...[
            _label(t.bankLabel),
            _bankDropdown(),
            const SizedBox(height: 12),
          ],
          if (_type != AccountType.cash) ...[
            _label(t.accountNumberLabel),
            _textField(
              controller: _numberCtrl,
              hint: t.accountNumberHint,
              keyboardType: TextInputType.number,
              onClear: () => _numberCtrl.clear(),
            ),
            const SizedBox(height: 12),
          ],
          _label(t.initialBalanceOptional),
          _textField(
            controller: _balanceCtrl,
            hint: '0',
            keyboardType: TextInputType.number,
            prefix: 'Rp',
            onClear: () => _balanceCtrl.clear(),
          ),
          const SizedBox(height: 20),
          // Warna & icon.
          Text(
            t.colorAndIcon,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Color(_color),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  accountIcon(_type),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: colors.map((c) {
                    final selected = c.value == _color;
                    return GestureDetector(
                      onTap: () => setState(() => _color = c.value),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(c.value),
                          border: selected
                              ? Border.all(
                                  color: scheme.onSurface,
                                  width: 2.5,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                t.saveAccount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? prefix,
    required VoidCallback onClear,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix != null ? '$prefix  ' : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () {
                    onClear();
                    setState(() {});
                  },
                ),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _bankDropdown() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: commonBanks.contains(_bankName) ? _bankName : null,
          isExpanded: true,
          hint: Text(
            _bankName ?? 'BCA (Bank Central Asia)',
            style: TextStyle(color: scheme.onSurface),
          ),
          items: commonBanks
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: (v) => setState(() => _bankName = v),
        ),
      ),
    );
  }
}
