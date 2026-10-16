import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../goals_store.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/mascot_image.dart';

/// Tujuan nabung ala mockup: kartu utama (featured) + daftar goal lain.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _store = GoalsStore();
  List<SavingGoal> _goals = [];
  bool _ready = false;

  static const _palette = [
    0xFF2F80ED,
    0xFF27AE60,
    0xFF9B51E0,
    0xFFF2994A,
    0xFFEB5757,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await _store.list();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _ready = true;
    });
  }

  Future<void> _addGoal() async {
    final t = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.addGoal),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: t.goalName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: t.targetAmount,
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': nameCtrl.text.trim(),
              'target': int.tryParse(targetCtrl.text.trim()) ?? 0,
            }),
            child: Text(t.save),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    targetCtrl.dispose();
    if (result == null) return;
    final name = result['name'] as String;
    final target = result['target'] as int;
    if (name.isEmpty || target <= 0) return;
    await _store.add(
      SavingGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        target: target,
        saved: 0,
        color: _palette[_goals.length % _palette.length],
      ),
    );
    _load();
  }

  Future<void> _addFunds(SavingGoal goal) async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.addFunds),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: 'Rp '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(t.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (amount == null || amount <= 0) return;
    await _store.addFunds(goal.id, amount);
    _load();
  }

  Future<void> _deleteGoal(SavingGoal goal) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteGoalTitle),
        content: Text(t.deleteGoalMessage(goal.name)),
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
    if (confirm != true) return;
    await _store.remove(goal.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.goalsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: t.addGoal,
            onPressed: _addGoal,
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 110),
              child: EmptyState(
                mascot: const MascotImage.goal(size: 120),
                title: t.noGoalsTitle,
                subtitle: t.noGoalsSubtitle,
                actionLabel: t.createGoal,
                onAction: _addGoal,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
              children: [
                _FeaturedGoalCard(
                  goal: _goals.first,
                  onAddFunds: () => _addFunds(_goals.first),
                  onDelete: () => _deleteGoal(_goals.first),
                ),
                if (_goals.length > 1)
                  for (final goal in _goals.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _GoalListTile(
                        goal: goal,
                        onTap: () => _addFunds(goal),
                        onDelete: () => _deleteGoal(goal),
                      ),
                    ),
              ],
            ),
    );
  }
}

/// Kartu goal utama: ilustrasi maskot, nama, target, progress + persen,
/// dan nominal terkumpul.
class _FeaturedGoalCard extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback onAddFunds;
  final VoidCallback onDelete;

  const _FeaturedGoalCard({
    required this.goal,
    required this.onAddFunds,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = Color(goal.color);
    final pct = goal.target == 0
        ? 0.0
        : (goal.saved / goal.target).clamp(0.0, 1.0);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAddFunds,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.35),
                    color.withValues(alpha: 0.10),
                  ],
                ),
              ),
              child: const Center(child: MascotImage.hero(size: 96)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: scheme.onSurfaceVariant,
                        tooltip: AppLocalizations.of(context).delete,
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(goal.target),
                    style: DuitQuTheme.amountStyle(context, 18),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.7),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(pct * 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.collected(formatRupiah(goal.saved)),
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
    );
  }
}

/// Baris goal lain: icon tinted, nama + target, progress bar + persen.
class _GoalListTile extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GoalListTile({
    required this.goal,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(goal.color);
    final pct = goal.target == 0
        ? 0.0
        : (goal.saved / goal.target).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(DuitQuTheme.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.flag_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          formatRupiah(goal.target),
                          style: DuitQuTheme.amountStyle(context, 14),
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
                              value: pct,
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.7),
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: scheme.onSurfaceVariant,
                tooltip: AppLocalizations.of(context).delete,
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
