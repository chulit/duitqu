import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../chat/chat_controller.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';

/// Form edit khusus hasil scan struk (mockup Screen 5).
/// Field: Merchant, Jumlah, Tanggal, Akun, Kategori, Catatan, Items.
/// Tombol: Batal (merah) + Simpan Transaksi (biru).
class ScanEditSheet extends StatefulWidget {
  final ChatMsg msg;
  final TransactionRepository txRepo;
  final CategoryRepository categoryRepo;
  final AccountRepository accountRepo;
  final void Function(Transaction savedTx) onSaved;

  const ScanEditSheet({
    super.key,
    required this.msg,
    required this.txRepo,
    required this.categoryRepo,
    required this.accountRepo,
    required this.onSaved,
  });

  @override
  State<ScanEditSheet> createState() => _ScanEditSheetState();
}

class _ScanEditSheetState extends State<ScanEditSheet> {
  late final TextEditingController _merchantCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _accountId;
  List<Category> _categories = [];
  List<Account> _accounts = [];
  final List<_ItemRow> _items = [];

  @override
  void initState() {
    super.initState();
    final msg = widget.msg;
    _merchantCtrl = TextEditingController(text: msg.parsed?.description ?? '');
    _amountCtrl =
        TextEditingController(text: msg.parsed?.amount.toString() ?? '');
    _noteCtrl = TextEditingController();
    _date = msg.occurredAt;
    _categoryId = msg.categoryId;
    _accountId = msg.accountId;
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    final cats = await widget.categoryRepo.list();
    final accs = await widget.accountRepo.list();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _accounts = accs;
    });
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year, picked.month, picked.day,
          _date.hour, _date.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final amount =
        int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0 || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.formIncomplete)),
      );
      return;
    }
    // Salin gambar struk ke app-private storage (bila ada).
    String? receiptPath;
    if (widget.msg.imagePath != null) {
      receiptPath = await _storeImage(widget.msg.imagePath!);
    }
    final tx = Transaction(
      type: TransactionType.expense,
      amount: amount,
      categoryId: _categoryId,
      accountId: _accountId!,
      merchant: _merchantCtrl.text.trim().isEmpty
          ? null
          : _merchantCtrl.text.trim(),
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
      origin: TransactionOrigin.chat,
      receiptImagePath: receiptPath,
      items: _items
          .map((i) => TransactionItem(
                name: i.nameCtrl.text.trim(),
                price: int.tryParse(i.priceCtrl.text.replaceAll(
                        RegExp(r'[^0-9]'), '')) ??
                    0,
                qty: int.tryParse(i.qtyCtrl.text) ?? 1,
              ))
          .where((i) => i.name.isNotEmpty && i.price > 0)
          .toList(),
    );
    await widget.txRepo.save(tx);
    widget.msg.done = true;
    widget.onSaved(tx);
    if (mounted) Navigator.pop(context);
  }

  Future<String?> _storeImage(String srcPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(dir.path, 'receipts'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final ext = p.extension(srcPath);
      final name =
          'struk_${DateTime.now().millisecondsSinceEpoch}$ext';
      final dest = p.join(receiptsDir.path, name);
      await File(srcPath).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle.
            Center(
              child: Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _label(t.merchantLabel),
            TextField(
              controller: _merchantCtrl,
              decoration: _deco(scheme),
            ),
            const SizedBox(height: 12),
            _label(t.amountLabel),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: _deco(scheme, prefix: 'Rp '),
            ),
            const SizedBox(height: 12),
            _label(t.dateLabel),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: _deco(scheme),
                child: Text(formatTanggal(_date, t)),
              ),
            ),
            const SizedBox(height: 12),
            _label(t.accountLabel),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: _deco(scheme),
              items: _accounts
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            _label(t.categoryLabel),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: _deco(scheme),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            _label(t.noteLabel),
            TextField(
              controller: _noteCtrl,
              decoration: _deco(scheme),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  t.itemsLabel,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemRow())),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t.addItem),
                ),
              ],
            ),
            for (int i = 0; i < _items.length; i++)
              _itemRow(_items[i], () => setState(() => _items.removeAt(i))),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    t.cancel,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  child: Text(t.saveTransaction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );

  InputDecoration _deco(ColorScheme scheme, {String? prefix}) =>
      InputDecoration(
        prefixText: prefix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _itemRow(_ItemRow item, VoidCallback onDelete) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.nameCtrl,
              decoration: InputDecoration(
                hintText: t.itemName,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: item.qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: t.qty,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: t.price,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.remove_circle_outline_rounded,
                color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ItemRow {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
}
