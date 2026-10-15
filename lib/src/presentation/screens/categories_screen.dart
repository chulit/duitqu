import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../category_icons.dart';
import '../l10n/app_localizations.dart';

/// Kelola kategori: daftar + tambah + hapus (bawaan read-only).
class CategoriesScreen extends StatefulWidget {
  final CategoryRepository categoryRepo;

  const CategoriesScreen({super.key, required this.categoryRepo});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  Future<void> _addCategory() async {
    final t = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.categoriesTitle),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(labelText: t.categoryLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.isEmpty) return;
    const palette = [
      0xFF2F80ED,
      0xFF27AE60,
      0xFF9B51E0,
      0xFFF2994A,
      0xFFEB5757,
    ];
    final existing = await widget.categoryRepo.list();
    await widget.categoryRepo.save(
      Category(
        name: name,
        icon: 'shapes',
        color: palette[existing.length % palette.length],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(Category c) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.delete),
        content: Text('"${c.name}"'),
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
    if (ok != true || !mounted) return;
    try {
      await widget.categoryRepo.delete(c.id!);
      setState(() {});
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.categoriesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addCategory,
          ),
        ],
      ),
      body: FutureBuilder<List<Category>>(
        future: widget.categoryRepo.list(),
        builder: (context, snapshot) {
          final cats = snapshot.data ?? [];
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: cats.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = cats[i];
              final color = Color(c.color);
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(categoryIcon(c.icon), color: color),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: c.isDefault
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: scheme.onSurfaceVariant,
                          onPressed: () => _delete(c),
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
