import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transfer_service.dart';
import '../format.dart';
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

/// Bottom sheet catat kilat: maksimal 2 tap dari layar utama.
/// Dipakai untuk tambah baru maupun edit ([existing]).
class AddTransactionSheet extends StatefulWidget {  final TransactionRepository txRepo;
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

    // Kumpulkan item: baris yang sepenuhnya kosong dilewati,
    // baris yang terisi sebagian divalidasi.
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: bottom + 16),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEdit ? 'Ubah transaksi' : 'Catat transaksi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Keluar'),
                        icon: Icon(Icons.arrow_upward),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Masuk'),
                        icon: Icon(Icons.arrow_downward),
                      ),
                      ButtonSegment(
                        value: TransactionType.transfer,
                        label: Text('Transfer'),
                        icon: Icon(Icons.swap_horiz),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() {
                      _type = s.single;
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
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('amountField'),
                    controller: _amountCtrl,
                    autofocus: !_isEdit,
                    enabled: _itemDrafts.isEmpty,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    decoration: InputDecoration(
                      labelText: _itemDrafts.isEmpty
                          ? 'Nominal (Rp)'
                          : 'Total otomatis dari item',
                      border: const OutlineInputBorder(),
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_type != TransactionType.transfer) ...[
                    const Text('Kategori'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in _categories)
                          ChoiceChip(
                            label: Text(c.name),
                            selected: _categoryId == c.id,
                            onSelected: (_) =>
                                setState(() => _categoryId = c.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: const Key('fromAccountDropdown'),
                          initialValue: _accountId,
                          decoration: InputDecoration(
                            labelText: _type == TransactionType.transfer
                                ? 'Dari akun'
                                : 'Akun',
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final a in _accounts)
                              DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _accountId = v),
                        ),
                      ),
                      if (_type == TransactionType.transfer) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: const Key('toAccountDropdown'),
                            initialValue: _toAccountId,
                            decoration: const InputDecoration(
                              labelText: 'Ke akun',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final a in _accounts)
                                if (a.id != _accountId)
                                  DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name),
                                  ),
                            ],
                            onChanged: (v) =>
                                setState(() => _toAccountId = v),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_type == TransactionType.transfer && !_isEdit) ...[
                    TextField(
                      key: const Key('feeField'),
                      controller: _feeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Biaya admin (opsional)',
                        helperText:
                            'Otomatis tercatat sebagai pengeluaran "Biaya Admin".',
                        border: OutlineInputBorder(),
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(formatTanggal(_date)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Autocomplete<String>(
                          initialValue:
                              TextEditingValue(text: _merchant),
                          optionsBuilder: (value) {
                            if (value.text.isEmpty) {
                              return _merchants;
                            }
                            final q = value.text.toLowerCase();
                            return _merchants.where(
                              (m) => m.toLowerCase().contains(q),
                            );
                          },
                          onSelected: (v) => _merchant = v,
                          fieldViewBuilder:
                              (ctx, ctrl, focus, onSubmit) {
                            return TextField(
                              controller: ctrl,
                              focusNode: focus,
                              onChanged: (v) => _merchant = v,
                              decoration: const InputDecoration(
                                labelText: 'Merchant (opsional)',
                                border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_type != TransactionType.transfer) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Rincian item (opsional)'),
                        const Spacer(),
                        TextButton.icon(
                          key: const Key('addItemButton'),
                          onPressed: () => setState(() {
                            _itemDrafts.add(_ItemDraft());
                            _syncAmountFromItems();
                          }),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah item'),
                        ),
                      ],
                    ),
                    for (var i = 0; i < _itemDrafts.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                key: Key('itemName_$i'),
                                controller: _itemDrafts[i].nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nama barang',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                key: Key('itemPrice_$i'),
                                controller: _itemDrafts[i].priceCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                onChanged: (_) => setState(
                                    _syncAmountFromItems),
                                decoration: const InputDecoration(
                                  labelText: 'Harga',
                                  border: OutlineInputBorder(),
                                  prefixText: 'Rp ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                key: Key('itemQty_$i'),
                                controller: _itemDrafts[i].qtyCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                onChanged: (_) => setState(
                                    _syncAmountFromItems),
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              key: Key('itemDelete_$i'),
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => setState(() {
                                _itemDrafts.removeAt(i).dispose();
                                if (_itemDrafts.isEmpty) {
                                  _amountCtrl.clear();
                                } else {
                                  _syncAmountFromItems();
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                    if (_itemDrafts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total: ${formatRupiah(_itemsTotal)}',
                            style: DuitQuTheme.amountStyle(
                              context,
                              16,
                              color: _type == TransactionType.income
                                  ? DuitQuTheme.emerald
                                  : DuitQuTheme.terracotta,
                            ),
                          ),
                        ),
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('saveButton'),
                    onPressed: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_isEdit ? 'Simpan perubahan' : 'Catat'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
