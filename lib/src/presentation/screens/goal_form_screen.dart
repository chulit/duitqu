import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../goals_store.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/mascot_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Form Buat/Edit Tujuan ala mockup.
class GoalFormScreen extends StatefulWidget {
  final SavingGoal? existing;

  const GoalFormScreen({super.key, this.existing});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  late GoalCategory _category;
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? GoalCategory.rumah;
    if (e != null) {
      _nameCtrl.text = e.name;
      _targetCtrl.text = e.target.toString();
      _noteCtrl.text = e.note ?? '';
      _deadline = e.deadline;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _submit() {
    final t = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    final target = int.tryParse(_targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (name.isEmpty || target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.goalFormInvalid)),
      );
      return;
    }
    final existing = widget.existing;
    final goal = SavingGoal(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      target: target,
      saved: existing?.saved ?? 0,
      category: _category,
      deadline: _deadline,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      contributions: existing?.contributions ?? const [],
    );
    Navigator.pop(context, goal);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            widget.existing == null ? t.createGoalTitle : t.editGoalTitle,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.createGoalSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          // Kategori Tujuan.
          Text(
            t.goalCategory,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: GoalCategory.values.length,
            itemBuilder: (ctx, i) {
              final c = GoalCategory.values[i];
              final selected = c == _category;
              return InkWell(
                onTap: () => setState(() => _category = c),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? DuitQuTheme.primaryBlue.withValues(alpha: 0.08)
                        : scheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? DuitQuTheme.primaryBlue
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        c.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected
                              ? DuitQuTheme.primaryBlue
                              : scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Nama Tujuan.
          _Label(t.goalName),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: t.goalNameHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _nameCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () =>
                          setState(() => _nameCtrl.clear()),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // Target Nominal.
          _Label(t.goalTargetAmount),
          const SizedBox(height: 8),
          TextField(
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixText: 'Rp ',
              hintText: '50.000.000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Target Tanggal.
          _Label(t.goalTargetDate),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _deadline == null
                          ? t.goalDateHint
                          : formatTanggal(_deadline!, t),
                      style: TextStyle(
                        fontSize: 15,
                        color: _deadline == null
                            ? scheme.onSurfaceVariant
                                .withValues(alpha: 0.6)
                            : null,
                      ),
                    ),
                  ),
                  if (_deadline != null)
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () =>
                          setState(() => _deadline = null),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Catatan.
          _Label(t.goalNoteOptional),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            maxLength: 100,
            decoration: InputDecoration(
              hintText: t.goalNoteHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // Ringkasan.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DuitQuTheme.primaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.goalSummary,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      label: Text(t.editLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _category.emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameCtrl.text.isEmpty
                                ? '—'
                                : _nameCtrl.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (_noteCtrl.text.isNotEmpty)
                            Text(
                              _noteCtrl.text,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryItem(
                        icon: LucideIcons.crosshair,
                        label: t.goalTargetAmount,
                        value: _targetCtrl.text.isEmpty
                            ? '—'
                            : 'Rp ${_targetCtrl.text}',
                      ),
                    ),
                    Expanded(
                      child: _SummaryItem(
                        icon: LucideIcons.calendar,
                        label: t.goalTargetDate,
                        value: _deadline == null
                            ? '—'
                            : formatTanggal(_deadline!, t),
                      ),
                    ),
                    Expanded(
                      child: _SummaryItem(
                        icon: LucideIcons.layoutGrid,
                        label: t.goalCategory,
                        value: _category.label,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tips maskot.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const MascotImage.idea(size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.goalTipTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.goalTipBody,
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
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                widget.existing == null ? t.createGoal : t.saveLabel,
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
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
