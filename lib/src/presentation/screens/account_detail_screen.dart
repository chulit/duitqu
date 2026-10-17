import 'package:flutter/material.dart';

import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../category_icons.dart';
import '../l10n/app_localizations.dart';
import '../format.dart';
import 'accounts_screen.dart';
import 'account_form_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Detail akun ala mockup: header + info + riwayat saldo + aksi.
class AccountDetailScreen extends StatefulWidget {
  final Account account;
  final AccountRepository accountRepo;

  const AccountDetailScreen({
    super.key,
    required this.account,
    required this.accountRepo,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late Account _account;
  int _balance = 0;
  List<int> _history = [];
  List<String> _historyLabels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _load();
  }

  Future<void> _load() async {
    final t = AppLocalizations.of(context);
    final balance = await widget.accountRepo.balance(_account.id!);
    // Riwayat 6 bulan terakhir (saldo per akhir bulan).
    final now = DateTime.now();
    final history = <int>[];
    final labels = <String>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final end = DateTime(m.year, m.month + 1, 0, 23, 59, 59);
      final upTo = end.isAfter(now) ? now : end;
      history.add(
        await widget.accountRepo.balance(_account.id!, upTo: upTo),
      );
      labels.add(t.shortMonth(m.month));
    }
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _history = history;
      _historyLabels = labels;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountFormScreen(
          accountRepo: widget.accountRepo,
          existing: _account,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    // Ambil ulang data terbaru.
    final accounts = await widget.accountRepo.list();
    final updated = accounts.where((a) => a.id == _account.id).firstOrNull;
    if (updated != null) {
      setState(() {
        _account = updated;
        _loading = true;
      });
      await _load();
    }
  }

  Future<void> _confirmDelete() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteAccountTitle),
        content: Text(t.deleteAccountMessage(_account.name)),
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
      await widget.accountRepo.delete(_account.id!);
      if (mounted) Navigator.pop(context, true);
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _moreMenu() {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: Text(t.editAccountBtn),
              onTap: () {
                Navigator.pop(ctx);
                _edit();
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                t.deleteAccountBtn,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = Color(_account.color);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.detailAccountTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.ellipsis),
            onPressed: _moreMenu,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Header card.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              accountIcon(_account.type),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _account.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  accountTypeLabel(_account.type, t),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.pencil, size: 20),
                            onPressed: _edit,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  scheme.surface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.currentBalance,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(_balance),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Detail rows.
                _DetailRow(
                  icon: LucideIcons.landmark,
                  label: t.accountTypeLabel,
                  value: accountTypeLabel(_account.type, t),
                ),
                if (_account.bankName != null)
                  _DetailRow(
                    icon: LucideIcons.building2,
                    label: t.bankLabel,
                    value: _account.bankName!,
                  ),
                if (_account.accountNumber != null)
                  _DetailRow(
                    icon: LucideIcons.creditCard,
                    label: t.accountNumberLabel
                        .replaceAll(' (opsional)', '')
                        .replaceAll(' (optional)', ''),
                    value: _account.accountNumber!,
                  ),
                _DetailRow(
                  icon: LucideIcons.palette,
                  label: t.colorLabel,
                  valueWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _colorName(_account.color, t),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Riwayat saldo.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.balanceHistory,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 120,
                        child: CustomPaint(
                          painter: _BalanceHistoryPainter(
                            values: _history,
                            labels: _historyLabels,
                            textColor: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatRupiah(_balance),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatTanggal(DateTime.now(), t),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Tombol aksi.
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.tonalIcon(
                          onPressed: _edit,
                          icon: const Icon(LucideIcons.pencil, size: 18),
                          label: Text(t.editAccountBtn),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _confirmDelete,
                          icon: const Icon(LucideIcons.trash2, size: 18),
                          label: Text(t.deleteAccountBtn),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFDE8E8),
                            foregroundColor: const Color(0xFFEB5757),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _colorName(int value, AppLocalizations t) {
    switch (value) {
      case 0xFF2E9BFF:
        return t.colorBlue;
      case 0xFF27AE60:
        return t.colorGreen;
      case 0xFF9B51E0:
        return t.colorPurple;
      case 0xFFEB5757:
        return t.colorRed;
      case 0xFFF2994A:
        return t.colorOrange;
      case 0xFF14B8A6:
        return t.colorGreen;
      default:
        return t.colorGray;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          valueWidget ??
              Text(
                value ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ],
      ),
    );
  }
}

/// Mini bar chart riwayat saldo 6 bulan.
class _BalanceHistoryPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final Color textColor;

  _BalanceHistoryPainter({
    required this.values,
    required this.labels,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    const bottomPad = 20.0;
    final chartH = size.height - bottomPad;
    final n = values.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.5).clamp(8.0, 28.0);

    final labelStyle = TextStyle(color: textColor, fontSize: 10);
    for (var i = 0; i < n; i++) {
      final h = chartH * values[i] / maxVal;
      final x = slotW * i + (slotW - barW) / 2;
      final isLast = i == n - 1;
      final barPaint = Paint()
        ..color = isLast
            ? const Color(0xFF2E9BFF)
            : const Color(0xFF2E9BFF).withValues(alpha: 0.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartH - h, barW, h.clamp(4.0, chartH)),
          const Radius.circular(4),
        ),
        barPaint,
      );
      // Label bulan.
      if (i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(slotW * i + (slotW - tp.width) / 2, size.height - 16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceHistoryPainter old) =>
      old.values != values;
}
