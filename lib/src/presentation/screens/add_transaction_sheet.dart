import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Satu baris item belanja pada form (draft yang bisa diedit).
class _ItemDraft {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
  }
}

/// Bottom sheet catat kilat: nominal besar di atas, grid kategori berikon.
/// Dipakai untuk tambah baru maupun edit ([existing]).
class AddTransactionSheet extends StatefulWidget {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransferService transferService;
  final QuickAddDefaults defaults;
  final Transaction? existing;

  const AddTransactionSheet({
    super.key,
    required this.txRepo,
    required this.accountRepo,
    required this.categoryRepo,
    required this.transferService,
    required this.defaults,
    this.existing,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionType _type;
  final _amountCtrl = TextEditingController();
  int? _categoryId;
  int? _accountId;
  int? _toAccountId;
  DateTime _date = DateTime.now();
  String _merchant = '';
  final _noteCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _itemDrafts = <_ItemDraft>[];
  String? _error;

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  List<String> _merchants = const [];
  bool _loading = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _type = ex.type;
      _amountCtrl.text = ex.amount.toString();
      _categoryId = ex.categoryId;
      _accountId = ex.accountId;
      _toAccountId = ex.toAccountId;
      _date = ex.date;
      _merchant = ex.merchant ?? '';
      _noteCtrl.text = ex.note ?? '';
      for (final item in ex.items) {
        final d = _ItemDraft();
        d.nameCtrl.text = item.name;
        d.priceCtrl.text = item.price.toString();
        d.qtyCtrl.text = item.qty.toString();
        _itemDrafts.add(d);
      }
    } else {
      _type = widget.defaults.lastType;
      _categoryId = widget.defaults.lastCategoryId;
      _accountId = widget.defaults.lastAccountId;
    }
    _load();
  }

  Future<void> _load() async {
    final accounts = await widget.accountRepo.list();
    final categories = await widget.categoryRepo.list();
    final merchants = await widget.txRepo.merchantSuggestions();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _categories = categories;
      _merchants = merchants;
      _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
      _categoryId ??= categories.isNotEmpty ? categories.first.id : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _feeCtrl.dispose();
    for (final d in _itemDrafts) {
      d.dispose();
    }
    super.dispose();
  }

  /// Total otomatis dari item. Dipakai sebagai nominal saat ada item.
  int get _itemsTotal => _itemDrafts.fold<int>(0, (sum, d) {
    final price = int.tryParse(d.priceCtrl.text.trim()) ?? 0;
    final qty = int.tryParse(d.qtyCtrl.text.trim()) ?? 0;
    return sum + price * qty;
  });

  void _syncAmountFromItems() {
    if (_itemDrafts.isNotEmpty) {
      _amountCtrl.text = _itemsTotal.toString();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);

    final items = <TransactionItem>[];
    for (var i = 0; i < _itemDrafts.length; i++) {
      final d = _itemDrafts[i];
      final name = d.nameCtrl.text.trim();
      final priceText = d.priceCtrl.text.trim();
      final qtyText = d.qtyCtrl.text.trim();
      if (name.isEmpty && priceText.isEmpty && qtyText.isEmpty) continue;
      final price = int.tryParse(priceText);
      final qty = int.tryParse(qtyText);
      if (name.isEmpty) {
        setState(() => _error = 'Nama item baris ${i + 1} tidak boleh kosong.');
        return;
      }
      if (price == null || price < 0) {
        setState(() => _error = 'Harga item "$name" tidak valid.');
        return;
      }
      if (qty == null || qty <= 0) {
        setState(() => _error = 'Qty item "$name" harus lebih dari 0.');
        return;
      }
      items.add(TransactionItem(name: name, price: price, qty: qty));
    }

    final amount = items.isEmpty
        ? int.tryParse(_amountCtrl.text.trim()) ?? 0
        : items.fold<int>(0, (s, it) => s + it.total);
    if (amount <= 0) {
      setState(() => _error = 'Nominal harus lebih dari 0.');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Pilih akun dulu.');
      return;
    }
    if (_type == TransactionType.transfer) {
      if (_toAccountId == null || _toAccountId == _accountId) {
        setState(() => _error = 'Pilih akun tujuan yang berbeda.');
        return;
      }
    } else if (_categoryId == null) {
      setState(() => _error = 'Pilih kategori dulu.');
      return;
    }

    final ex = widget.existing;
    final tx = Transaction(
      id: ex?.id,
      type: _type,
      amount: amount,
      categoryId: _type == TransactionType.transfer ? null : _categoryId,
      accountId: _accountId!,
      toAccountId: _type == TransactionType.transfer ? _toAccountId : null,
      merchant: _merchant.trim().isEmpty ? null : _merchant.trim(),
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: ex?.createdAt ?? DateTime.now(),
      items: items,
    );
    try {
      if (_type == TransactionType.transfer) {
        final fee = int.tryParse(_feeCtrl.text.trim()) ?? 0;
        await widget.transferService.saveTransfer(tx, fee: fee);
      } else {
        await widget.txRepo.save(tx);
      }
    } on ArgumentError catch (e) {
      setState(() => _error = e.message);
      return;
    }
    widget.defaults.remember(
      accountId: _accountId,
      categoryId: _categoryId,
      type: _type,
    );
    if (mounted) Navigator.pop(context, true);
  }

  Color get _typeColor {
    switch (_type) {
      case TransactionType.income:
        return DuitQuTheme.incomeColor(context);
      case TransactionType.expense:
        return DuitQuTheme.expenseColor(context);
      case TransactionType.transfer:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollCtrl) => _loading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      children: [
                        Text(
                          _isEdit
                              ? t.editTransactionTitle
                              : t.addTransactionTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _TypeSelector(
                          type: _type,
                          onChanged: (v) => setState(() {
                            _type = v;
                            if (_type == TransactionType.transfer &&
                                _itemDrafts.isNotEmpty) {
                              for (final d in _itemDrafts) {
                                d.dispose();
                              }
                              _itemDrafts.clear();
                              _amountCtrl.clear();
                            }
                          }),
                        ),
                        const SizedBox(height: 20),
                        // Nominal besar — prioritas utama di layar catat.
                        TextField(
                          key: const Key('amountField'),
                          controller: _amountCtrl,
                          autofocus: !_isEdit,
                          enabled: _itemDrafts.isEmpty,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textAlign: TextAlign.center,
                          style: DuitQuTheme.amountStyle(
                            context,
                            40,
                            color: _typeColor,
                            weight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: _itemDrafts.isEmpty
                                ? t.amountLabel
                                : t.amountAutoLabel,
                            hintStyle: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            prefixText: 'Rp ',
                            prefixStyle: DuitQuTheme.amountStyle(
                              context,
                              24,
                              color: _typeColor.withValues(alpha: 0.7),
                              weight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_type != TransactionType.transfer) ...[
                          _SectionLabel(t.categoryLabel),
                          const SizedBox(height: 8),
                          _CategoryGrid(
                            categories: _categories
                                .where(
                                  (c) => _type == TransactionType.income
                                      ? _isIncomeCategory(c)
                                      : true,
                                )
                                .toList(),
                            selectedId: _categoryId,
                            onSelect: (id) => setState(() => _categoryId = id),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _SectionLabel(
                          _type == TransactionType.transfer
                              ? t.fromAccountLabel
                              : t.accountLabel,
                        ),
                        const SizedBox(height: 8),
                        _AccountChips(
                          accounts: _accounts,
                          selectedId: _accountId,
                          keyPrefix: 'fromAccountDropdown',
                          onSelect: (id) => setState(() => _accountId = id),
                        ),
                        if (_type == TransactionType.transfer) ...[
                          const SizedBox(height: 12),
                          _SectionLabel(t.toAccountLabel),
                          const SizedBox(height: 8),
                          _AccountChips(
                            accounts: _accounts
                                .where((a) => a.id != _accountId)
                                .toList(),
                            selectedId: _toAccountId,
                            keyPrefix: 'toAccountDropdown',
                            onSelect: (id) => setState(() => _toAccountId = id),
                          ),
                          if (!_isEdit) ...[
                            const SizedBox(height: 12),
                            TextField(
                              key: const Key('feeField'),
                              controller: _feeCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: t.adminFeeLabel,
                                helperText: t.adminFeeHint,
                                prefixText: 'Rp ',
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                ),
                                label: Text(formatTanggal(_date, t)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Autocomplete<String>(
                                initialValue: TextEditingValue(text: _merchant),
                                optionsBuilder: (value) {
                                  if (value.text.isEmpty) return _merchants;
                                  final q = value.text.toLowerCase();
                                  return _merchants.where(
                                    (m) => m.toLowerCase().contains(q),
                                  );
                                },
                                onSelected: (v) => _merchant = v,
                                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                                  return TextField(
                                    controller: ctrl,
                                    focusNode: focus,
                                    onChanged: (v) => _merchant = v,
                                    decoration: InputDecoration(
                                      labelText: t.merchantLabel,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteCtrl,
                          decoration: InputDecoration(labelText: t.noteLabel),
                        ),
                        if (_type != TransactionType.transfer) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                t.itemsSection,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                key: const Key('addItemButton'),
                                onPressed: () => setState(() {
                                  _itemDrafts.add(_ItemDraft());
                                  _syncAmountFromItems();
                                }),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(t.addItem),
                              ),
                            ],
                          ),
                          for (var i = 0; i < _itemDrafts.length; i++)
                            _ItemRow(
                              index: i,
                              draft: _itemDrafts[i],
                              onChanged: () => setState(_syncAmountFromItems),
                              onDelete: () => setState(() {
                                _itemDrafts.removeAt(i).dispose();
                                if (_itemDrafts.isEmpty) {
                                  _amountCtrl.clear();
                                } else {
                                  _syncAmountFromItems();
                                }
                              }),
                            ),
                          if (_itemDrafts.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Total: ${formatRupiah(_itemsTotal)}',
                                style: DuitQuTheme.amountStyle(
                                  context,
                                  16,
                                  color: _typeColor,
                                ),
                              ),
                            ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const Key('saveButton'),
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _typeColor,
                          ),
                          child: Text(_isEdit ? t.saveChanges : t.save),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Kategori pemasukan: Gaji & Bonus (bawaan). Kustom ikut expense.
  bool _isIncomeCategory(Category c) {
    if (!c.isDefault) return false;
    return c.name == 'Gaji' || c.name == 'Bonus';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Pilihan tipe: Keluar / Masuk / Transfer — pill berwarna.
class _TypeSelector extends StatelessWidget {
  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        TransactionType.expense,
        t.expense,
        Icons.arrow_upward_rounded,
        DuitQuTheme.expenseColor(context),
      ),
      (
        TransactionType.income,
        t.income,
        Icons.arrow_downward_rounded,
        DuitQuTheme.incomeColor(context),
      ),
      (
        TransactionType.transfer,
        t.transfer,
        Icons.swap_horiz_rounded,
        scheme.primary,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (value, label, icon, color) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: type == value
                        ? color.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: type == value ? color : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: type == value
                              ? color
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grid kategori berikon (4 kolom).
class _CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final c = categories[i];
        final selected = selectedId == c.id;
        final color = Color(c.color);
        return GestureDetector(
          onTap: () => onSelect(c.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.16)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: selected ? Border.all(color: color, width: 1.5) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(categoryIcon(c.icon), color: color, size: 24),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    c.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pilihan akun sebagai chips. [keyPrefix] dipakai untuk kompatibilitas
/// test lama (fromAccountDropdown / toAccountDropdown).
class _AccountChips extends StatelessWidget {
  final List<Account> accounts;
  final int? selectedId;
  final String keyPrefix;
  final ValueChanged<int?> onSelect;

  const _AccountChips({
    required this.accounts,
    required this.selectedId,
    required this.keyPrefix,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      key: Key(keyPrefix),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in accounts)
          ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(accountIcon(a.type), size: 16),
                const SizedBox(width: 6),
                Text(a.name),
              ],
            ),
            selected: selectedId == a.id,
            onSelected: (_) => onSelect(a.id),
            selectedColor: scheme.primary.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }
}

/// Satu baris item belanja.
class _ItemRow extends StatelessWidget {
  final int index;
  final _ItemDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: Key('itemName_$index'),
              controller: draft.nameCtrl,
              decoration: InputDecoration(labelText: t.itemName),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              key: Key('itemPrice_$index'),
              controller: draft.priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: t.price,
                prefixText: 'Rp ',
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              key: Key('itemQty_$index'),
              controller: draft.qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(labelText: t.qty),
            ),
          ),
          IconButton(
            key: Key('itemDelete_$index'),
            icon: const Icon(Icons.remove_circle_outline_rounded),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
