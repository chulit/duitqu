// ignore_for_file: unused_element, unused_field
// Helper backup/sinkronisasi & auto-record di bawah sengaja dipertahankan
// untuk wiring ulang berikutnya (tidak ditampilkan di UI mockup saat ini).
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
import '../locale_store.dart';
import '../theme_mode_store.dart';
import '../user_name_store.dart';
import '../widgets/mascot_image.dart';
import 'accounts_screen.dart';
import 'categories_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _autoRecordKey = 'duitqu.auto_record';

/// Halaman Akun ala mockup: header, kartu profil, menu berkelompok, logout.
class ProfileScreen extends StatefulWidget {
  final AccountRepository accountRepo;
  final CategoryRepository categoryRepo;
  final TransactionRepository txRepo;
  final BackupService backup;
  final ThemeModeStore themeStore;
  final LocaleStore localeStore;
  final UserNameStore nameStore;

  const ProfileScreen({
    super.key,
    required this.accountRepo,
    required this.categoryRepo,
    required this.txRepo,
    required this.backup,
    required this.themeStore,
    required this.localeStore,
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

  Future<void> _pickLanguage() async {
    final t = AppLocalizations.of(context);
    Locale? chosen;
    var didChoose = false;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<Locale?>(
          groupValue: widget.localeStore.value,
          onChanged: (v) {
            chosen = v;
            didChoose = true;
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<Locale?>(
                title: Text(t.languageIndonesian),
                value: const Locale('id'),
              ),
              RadioListTile<Locale?>(
                title: Text(t.languageEnglish),
                value: const Locale('en'),
              ),
              RadioListTile<Locale?>(
                title: Text(t.languageSystem),
                value: null,
              ),
            ],
          ),
        ),
      ),
    );
    if (didChoose) await widget.localeStore.setLocale(chosen);
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            // Header: judul + gear.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.accountTitle,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.accountSubtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(LucideIcons.settings, size: 22),
                    tooltip: t.menuSettings,
                    onPressed: () =>
                        _push(const AutoRecordSettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Kartu profil.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F2FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const MascotImage.avatar(size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: widget.nameStore,
                          builder: (context, name, _) => Text(
                            (name == null || name.isEmpty)
                                ? 'Dinda'
                                : name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // Placeholder: belum ada auth.
                          'dinda@gmail.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _editName,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.pencil,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.editProfile,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  LucideIcons.chevronRight,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Section Keuangan.
            _SectionTitle(t.financeSection),
            const SizedBox(height: 8),
            _MenuCard(
              children: [
                _MenuRow(
                  icon: LucideIcons.wallet,
                  iconColor: const Color(0xFF2E9BFF),
                  title: t.accountsMenu,
                  subtitle: t.accountsMenuDesc,
                  onTap: () => _push(
                    AccountsScreen(
                      accountRepo: widget.accountRepo,
                      txRepo: widget.txRepo,
                    ),
                  ),
                ),
                _MenuRow(
                  icon: LucideIcons.refreshCw,
                  iconColor: const Color(0xFF27AE60),
                  title: t.menuCategories,
                  subtitle: t.categoriesMenuDesc,
                  onTap: () => _push(
                    CategoriesScreen(categoryRepo: widget.categoryRepo),
                  ),
                ),
                _MenuRow(
                  icon: LucideIcons.tag,
                  iconColor: const Color(0xFF9B51E0),
                  title: t.paymentMethodMenu,
                  subtitle: t.paymentMethodMenuDesc,
                  onTap: _comingSoon,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Section Pengaturan.
            _SectionTitle(t.settingsSection),
            const SizedBox(height: 8),
            _MenuCard(
              children: [
                _MenuRow(
                  icon: LucideIcons.bell,
                  iconColor: const Color(0xFFF2994A),
                  title: t.notifMenu,
                  subtitle: t.notifMenuDesc,
                  onTap: _comingSoon,
                ),
                _MenuRow(
                  icon: LucideIcons.palette,
                  iconColor: const Color(0xFF2E9BFF),
                  title: t.displayMenu,
                  subtitle: t.displayMenuDesc,
                  onTap: _pickTheme,
                ),
                _MenuRow(
                  icon: LucideIcons.shieldCheck,
                  iconColor: const Color(0xFF27AE60),
                  title: t.privacyMenu,
                  subtitle: t.privacyMenuDesc,
                  onTap: _comingSoon,
                ),
                _MenuRow(
                  icon: LucideIcons.settings,
                  iconColor: const Color(0xFFBDBDBD),
                  title: t.otherMenu,
                  subtitle: t.otherMenuDesc,
                  onTap: _pickLanguage,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Section Tentang Aplikasi.
            _SectionTitle(t.aboutAppSection),
            const SizedBox(height: 8),
            _MenuCard(
              children: [
                _MenuRow(
                  icon: LucideIcons.info,
                  iconColor: const Color(0xFF2E9BFF),
                  title: t.menuAbout,
                  subtitle: '${t.versionLabel} 1.0.0',
                  onTap: _showAbout,
                ),
                _MenuRow(
                  icon: LucideIcons.helpCircle,
                  iconColor: const Color(0xFF9B51E0),
                  title: t.helpCenterMenu,
                  subtitle: t.helpCenterMenuDesc,
                  onTap: _comingSoon,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Logout.
            InkWell(
              onTap: _comingSoon,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.logOut,
                      size: 22,
                      color: Color(0xFFEB5757),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.logoutMenu,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEB5757),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<_MenuRow> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 72,
                  endIndent: 16,
                  color:
                      scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
