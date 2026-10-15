import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup_service.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../backup_sheet.dart';
import '../category_icons.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Lainnya: kelola kategori, backup CSV, tentang aplikasi.
class MoreScreen extends StatefulWidget {
  final CategoryRepository categoryRepo;
  final BackupService backup;

  const MoreScreen({
    super.key,
    required this.categoryRepo,
    required this.backup,
  });

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Future<void> _openBackup() async {
    await showModalBottomSheet(
      context: context,
      builder: (_) =>
          BackupSheet(onExport: _exportBackup, onImport: _importBackup),
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
        ShareParams(files: [XFile(file.path)], text: 'Backup DuitQu'),
      );
    } catch (e) {
      if (mounted) _showError(AppLocalizations.of(context).exportFailed(e));
    }
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked.isEmpty) return;
    final path = picked.single.path;
    if (path == null) return;
    try {
      final csv = await File(path).readAsString();
      final report = await widget.backup.importCsv(csv);
      if (mounted) {
        setState(() {});
        _showImportReport(report);
      }
    } on BackupFormatException catch (e) {
      if (mounted) {
        _showError(AppLocalizations.of(context).backupFormatMessage(e.code));
      }
    } catch (e) {
      if (mounted) {
        _showError(AppLocalizations.of(context).importFailed(e));
      }
    }
  }

  void _showError(String message) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.backupFailed),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.close)),
        ],
      ),
    );
  }

  void _showImportReport(ImportReport report) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.importDone),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.importSummary(
                  report.accounts,
                  report.categories,
                  report.transactions,
                  report.items,
                ),
              ),
              if (report.skipped.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  t.skippedRowsTitle(report.skipped.length),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...report.skipped.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      t.skippedRowLine(s.row, t.localizedSkippedReason(s)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.close)),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final t = AppLocalizations.of(context);
        return AlertDialog(
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
        );
      },
    );
    nameCtrl.dispose();
    if (name == null || name.isEmpty) return;
    // Warna & ikon default untuk kategori kustom.
    const palette = [
      0xFF0E7C5B,
      0xFF3E7CB1,
      0xFF7C5CBF,
      0xFFD64570,
      0xFFB8933E,
      0xFF3FA7A0,
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

  Future<void> _deleteCategory(Category c) async {
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
      appBar: AppBar(title: Text(t.navMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          _SectionHeader(
            title: t.categoriesTitle,
            action: TextButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.addItem),
            ),
          ),
          FutureBuilder<List<Category>>(
            future: widget.categoryRepo.list(),
            builder: (context, snapshot) {
              final cats = snapshot.data ?? [];
              if (cats.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: [
                    for (var i = 0; i < cats.length; i++) ...[
                      _CategoryTile(
                        category: cats[i],
                        onDelete: cats[i].isDefault
                            ? null
                            : () => _deleteCategory(cats[i]),
                      ),
                      if (i < cats.length - 1)
                        Divider(
                          indent: 68,
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: t.backupTitle),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.backup_rounded, color: scheme.primary),
                  ),
                  title: Text(t.backupTitle),
                  subtitle: Text(t.exportCsvSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: t.aboutTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: DuitQuTheme.emerald.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: DuitQuTheme.emerald,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        t.appTitle,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.aboutText,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          action ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback? onDelete;

  const _CategoryTile({required this.category, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(categoryIcon(category.icon), color: color),
      ),
      title: Text(
        category.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: onDelete == null
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: onDelete,
            ),
    );
  }
}
