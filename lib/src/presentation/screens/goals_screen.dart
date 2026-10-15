import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../goals_store.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Tujuan nabung ala mockup: kartu progres + tambah dana.
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.goalsTitle),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addGoal),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: DuitQuTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.flag_outlined,
                        size: 40,
                        color: DuitQuTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.noGoals,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _addGoal,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(t.addGoal),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
              itemCount: _goals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _GoalCard(
                goal: _goals[i],
                onAddFunds: () => _addFunds(_goals[i]),
                onDelete: () async {
                  await _store.remove(_goals[i].id);
                  _load();
                },
              ),
            ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback onAddFunds;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onAddFunds,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color = Color(goal.color);
    final pct = goal.target == 0
        ? 0.0
        : (goal.saved / goal.target).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(DuitQuTheme.radius),
        onTap: onAddFunds,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar placeholder gradien (bukan foto mockup).
            Container(
              height: 110,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.55),
                    color.withValues(alpha: 0.25),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.flag_rounded,
                  size: 44,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
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
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(goal.target),
                    style: DuitQuTheme.amountStyle(context, 17),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
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
                  const SizedBox(height: 6),
                  Text(
                    '${t.savedAmount} ${formatRupiah(goal.saved)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
