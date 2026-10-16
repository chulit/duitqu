import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backup_service.dart';
import 'auto_record_settings_screen.dart';
import 'sync_screen.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../backup_sheet.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../theme_mode_store.dart';
import '../user_name_store.dart';
import '../widgets/mascot_image.dart';
import 'accounts_screen.dart';
import 'categories_screen.dart';
import 'goals_screen.dart';

const _autoRecordKey = 'duitqu.auto_record';

/// Profil & Lainnya ala mockup: menu ke semua bagian aplikasi.
class ProfileScreen extends StatefulWidget {
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransactionRepository txRepo;
  final BackupService backup;
  final ThemeModeStore themeStore;
  final UserNameStore nameStore;

  const ProfileScreen({
    super.key,
    required this.accountRepo,
    required this.categoryRepo,
    required this.txRepo,
    required this.backup,
    required this.themeStore,
    required this.nameStore,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _autoRecord = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _autoRecord = prefs.getBool(_autoRecordKey) ?? false);
  }

  Future<void> _toggleAutoRecord(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRecordKey, v);
    if (mounted) setState(() => _autoRecord = v);
  }

  /// Dialog atur nama panggilan untuk sapaan di beranda.
  Future<void> _editName() async {
    final t = AppLocalizations.of(context);
    final ctrl =
        TextEditingController(text: widget.nameStore.value ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.userNameTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: t.userNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || !mounted) return;
    await widget.nameStore.setName(value.isEmpty ? null : value);
  }

  Future<void> _pickTheme() async {
    final t = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: widget.themeStore.value,
          onChanged: (v) => Navigator.pop(ctx, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(t.themeLight),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text(t.themeDark),
                value: ThemeMode.dark,
              ),
              RadioListTile<ThemeMode>(
                title: Text(t.themeSystem),
                value: ThemeMode.system,
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await widget.themeStore.setMode(picked);
  }

  void _openSync() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SyncScreen(backup: widget.backup)),
    );
  }

  void _openBackup() {
    showModalBottomSheet(
      context: context,
      builder: (_) =>
          BackupSheet(onExport: _exportBackup, onImport: _importBackup),
    );
  }

  Future<void> _exportBackup() async {
    final t = AppLocalizations.of(context);
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
      if (mounted) _showError(t.exportFailed(e));
    }
  }

  Future<void> _importBackup() async {
    final t = AppLocalizations.of(context);
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
      if (mounted) _showError(t.backupFormatMessage(e.code));
    } catch (e) {
      if (mounted) _showError(t.importFailed(e));
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

  void _showAbout() {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.menuAbout),
        content: Text(t.aboutText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.close)),
        ],
      ),
    );
  }

  void _comingSoon() {
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.comingSoon)));
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: t.menuSettings,
            onPressed: () => _push(const AutoRecordSettingsScreen()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(DuitQuTheme.radius),
              onTap: _editName,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: DuitQuTheme.primaryBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: MascotImage.avatar(size: 40)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<String?>(
                            valueListenable: widget.nameStore,
                            builder: (context, name, _) => Text(
                              (name == null || name.isEmpty)
                                  ? t.setName
                                  : name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.userNameHint,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            children: [
              _MenuRow(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFFF2994A),
                label: t.menuAccounts,
                onTap: () => _push(
                  AccountsScreen(
                    accountRepo: widget.accountRepo,
                    txRepo: widget.txRepo,
                  ),
                ),
              ),
              _MenuRow(
                icon: Icons.grid_view_rounded,
                iconColor: const Color(0xFF27AE60),
                label: t.menuCategories,
                onTap: () =>
                    _push(CategoriesScreen(categoryRepo: widget.categoryRepo)),
              ),
              _MenuRow(
                icon: Icons.savings_outlined,
                iconColor: DuitQuTheme.primaryBlue,
                label: t.menuBudget,
                onTap: _comingSoon,
              ),
              _MenuRow(
                icon: Icons.flag_outlined,
                iconColor: const Color(0xFF9B51E0),
                label: t.menuGoals,
                onTap: () => _push(const GoalsScreen()),
              ),
              _MenuRow(
                icon: Icons.auto_awesome_outlined,
                iconColor: const Color(0xFFF2994A),
                label: t.menuAutoRecord,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: DuitQuTheme.income.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _autoRecord ? t.active : 'v4',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DuitQuTheme.income,
                    ),
                  ),
                ),
                onTap: () => _toggleAutoRecord(!_autoRecord),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MenuCard(
            children: [
              _MenuRow(
                icon: Icons.backup_outlined,
                iconColor: const Color(0xFF27AE60),
                label: t.menuBackupSync,
                onTap: _openBackup,
              ),
              _MenuRow(
                icon: Icons.cloud_outlined,
                iconColor: const Color(0xFF2D9CDB),
                label: t.cloudSync,
                onTap: _openSync,
              ),
              _MenuRow(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFFEB5757),
                label: t.menuSecurity,
                onTap: _comingSoon,
              ),
              _MenuRow(
                icon: Icons.settings_outlined,
                iconColor: scheme.onSurfaceVariant,
                label: t.menuSettings,
                onTap: () => _push(const AutoRecordSettingsScreen()),
              ),
              _MenuRow(
                icon: Icons.brightness_6_outlined,
                iconColor: const Color(0xFFF2994A),
                label: t.theme,
                trailing: ValueListenableBuilder<ThemeMode>(
                  valueListenable: widget.themeStore,
                  builder: (context, mode, _) => Text(
                    switch (mode) {
                      ThemeMode.light => t.themeLight,
                      ThemeMode.dark => t.themeDark,
                      ThemeMode.system => t.themeSystem,
                    },
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                onTap: _pickTheme,
              ),
              _MenuRow(
                icon: Icons.help_outline_rounded,
                iconColor: DuitQuTheme.primaryBlue,
                label: t.menuHelp,
                onTap: _comingSoon,
              ),
              _MenuRow(
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFF9B51E0),
                label: t.menuAbout,
                onTap: _showAbout,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  t.appTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  t.aboutText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing:
          trailing ??
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
    );
  }
}
