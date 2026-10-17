import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../goals_store.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/chart_painters.dart';
import '../widgets/mascot_image.dart';
import 'goal_form_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Detail tujuan ala mockup: progress + chart + transaksi + aksi.
class GoalDetailScreen extends StatefulWidget {
  final String goalId;
  final GoalsStore store;

  const GoalDetailScreen({
    super.key,
    required this.goalId,
    required this.store,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  SavingGoal? _goal;
  int _chartRange = 6;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await widget.store.list();
    if (!mounted) return;
    setState(() {
      _goal = goals.firstWhere(
        (g) => g.id == widget.goalId,
        orElse: () => goals.first,
      );
    });
  }

  Future<void> _addFunds() async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.addFundsTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: '100.000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  final v = int.tryParse(
                    ctrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                  Navigator.pop(ctx, v);
                },
                child: Text(t.saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
    if (amount != null && amount > 0) {
      await widget.store.addFunds(_goal!.id, amount);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.fundsAdded(formatRupiah(amount)))),
        );
      }
    }
  }

  Future<void> _markComplete() async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.markCompleteTitle),
        content: Text(t.markCompleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.yesLabel),
          ),
        ],
      ),
    );
    if (confirm == true && _goal != null) {
      final g = _goal!;
      await widget.store.update(
        g.copyWith(saved: g.target),
      );
      _load();
    }
  }

  Future<void> _editGoal() async {
    final result = await Navigator.push<SavingGoal>(
      context,
      MaterialPageRoute(
        builder: (_) => GoalFormScreen(existing: _goal),
      ),
    );
    if (result != null) {
      await widget.store.update(result);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final goal = _goal;

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pct = (goal.progress * 100).round();
    final color = Color(goal.color);

    // Chart perkembangan: agregasi per bulan.
    final now = DateTime.now();
    final chartStart = DateTime(now.year, now.month - _chartRange + 1);
    final monthly = List<int>.filled(_chartRange, 0);
    final labels = <String>[];
    for (var i = 0; i < _chartRange; i++) {
      final d = DateTime(chartStart.year, chartStart.month + i);
      labels.add(t.shortMonth(d.month));
    }
    for (final c in goal.contributions) {
      final idx = (c.date.year - chartStart.year) * 12 +
          (c.date.month - chartStart.month);
      if (idx >= 0 && idx < _chartRange) monthly[idx] += c.amount;
    }

    // Transaksi terbaru (kontribusi).
    final recent = [...goal.contributions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: _editGoal,
            icon: const Icon(LucideIcons.pencil, size: 16),
            label: Text(t.editLabel),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            goal.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (goal.note != null) ...[
            const SizedBox(height: 4),
            Text(
              goal.note!,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Terkumpul vs Target.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.collectedLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatRupiah(goal.saved),
                      style: DuitQuTheme.amountStyle(context, 20),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    t.targetLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatRupiah(goal.target),
                    style: TextStyle(
                      fontSize: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Target Tanggal + Kategori.
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: LucideIcons.calendar,
                  label: t.goalTargetDate,
                  value: goal.deadline == null
                      ? '—'
                      : formatTanggal(goal.deadline!, t),
                  onTap: goal.isExpired ? _editGoal : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  icon: LucideIcons.layoutGrid,
                  label: t.goalCategory,
                  value: goal.category.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Kartu motivasi.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const MascotImage.idea(size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.goalMotivationTitle(pct),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.goalMotivationBody,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Perkembangan.
          Row(
            children: [
              Expanded(
                child: Text(
                  t.progressTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _RangePicker(
                range: _chartRange,
                onChanged: (v) => setState(() => _chartRange = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _GoalBarsPainter(
                values: monthly,
                labels: labels,
                textColor: scheme.onSurfaceVariant,
                barColor: color,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 20),
          // Transaksi Terbaru.
          Row(
            children: [
              Expanded(
                child: Text(
                  t.recentTransactions,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.seeAll),
                    const Icon(LucideIcons.chevronRight, size: 18),
                  ],
                ),
              ),
            ],
          ),
          for (final c in recent.take(5))
            _ContributionRow(contribution: c),
          const SizedBox(height: 20),
          // Tambah Tabungan.
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: goal.isCompleted ? null : _addFunds,
              icon: const Icon(LucideIcons.plus),
              label: Text(t.addFunds),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editGoal,
                  icon: const Icon(LucideIcons.calendar, size: 18),
                  label: Text(t.editTarget),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: goal.isCompleted ? null : _markComplete,
                  icon: const Icon(LucideIcons.checkCircle, size: 18),
                  label: Text(t.markComplete),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(LucideIcons.chevronRight, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  final int range;
  final ValueChanged<int> onChanged;

  const _RangePicker({
    required this.range,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      initialValue: range,
      onSelected: onChanged,
      itemBuilder: (ctx) => [
        for (final r in [3, 6, 12])
          PopupMenuItem(
            value: r,
            child: Text(t.monthsLabel(r)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.lastMonths(range),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  final GoalContribution contribution;

  const _ContributionRow({required this.contribution});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DuitQuTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.piggyBank,
              color: DuitQuTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contribution.source ?? t.savingsLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  formatTanggal(contribution.date, t),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${formatRupiah(contribution.amount)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF27AE60),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar chart dengan label nilai di atas tiap bar.
class _GoalBarsPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final Color textColor;
  final Color barColor;

  _GoalBarsPainter({
    required this.values,
    required this.labels,
    required this.textColor,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    const topPad = 24.0;
    const bottomPad = 24.0;
    final chartH = size.height - topPad - bottomPad;
    final n = values.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.5).clamp(16.0, 48.0);

    // Highlight bar tertinggi.
    var maxIdx = 0;
    for (var i = 1; i < n; i++) {
      if (values[i] > values[maxIdx]) maxIdx = i;
    }

    for (var i = 0; i < n; i++) {
      final h = chartH * values[i] / maxVal;
      final x = slotW * i + (slotW - barW) / 2;
      final isMax = i == maxIdx;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topPad + chartH - h, barW, h.clamp(0, chartH)),
          const Radius.circular(6),
        ),
        Paint()
          ..color = isMax
              ? barColor
              : barColor.withValues(alpha: 0.35),
      );
      // Label nilai di atas.
      if (values[i] > 0) {
        paintLabel(
          canvas,
          shortAxis(values[i]),
          Offset(x + barW / 2 - 16, topPad + chartH - h - 18),
          textColor,
          fontSize: 11,
        );
      }
      // Label bulan.
      if (i < labels.length) {
        paintLabel(
          canvas,
          labels[i],
          Offset(slotW * i + slotW / 2 - 12, size.height - bottomPad + 6),
          textColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoalBarsPainter old) =>
      old.values != values;
}
