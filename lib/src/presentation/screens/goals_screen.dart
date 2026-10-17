import 'package:flutter/material.dart';

import '../format.dart';
import '../goals_store.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'goal_detail_screen.dart';
import 'goal_form_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Layar Tujuan ala mockup: hero Tabungan Utama + Aktif + Kadaluarsa + Selesai.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _store = GoalsStore();
  List<SavingGoal> _goals = [];
  bool _ready = false;
  bool _showExpired = true;
  bool _showCompleted = false;

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

  /// Tabungan Utama = target terbesar dari yang aktif (otomatis).
  SavingGoal? get _primary {
    final active = _goals.where((g) => !g.isCompleted && !g.isExpired);
    if (active.isEmpty) return null;
    return active.reduce((a, b) => a.target >= b.target ? a : b);
  }

  List<SavingGoal> get _active =>
      _goals.where((g) => !g.isCompleted && !g.isExpired).toList()
        ..sort((a, b) => b.target.compareTo(a.target));

  List<SavingGoal> get _expired =>
      _goals.where((g) => g.isExpired).toList()
        ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

  List<SavingGoal> get _completed =>
      _goals.where((g) => g.isCompleted).toList();

  Future<void> _openForm({SavingGoal? existing}) async {
    final result = await Navigator.push<SavingGoal>(
      context,
      MaterialPageRoute(
        builder: (_) => GoalFormScreen(existing: existing),
      ),
    );
    if (result != null) {
      if (existing != null) {
        await _store.update(result);
      } else {
        await _store.add(result);
      }
      _load();
    }
  }

  Future<void> _openDetail(SavingGoal goal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalDetailScreen(
          goalId: goal.id,
          store: _store,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final primary = _primary;
    final active = _active;
    final expired = _expired;
    final completed = _completed;

    return Scaffold(
      body: _goals.isEmpty
          ? _EmptyGoals(t: t, onCreate: () => _openForm())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                // Header.
                Text(
                  t.goalsTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.goalsSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                // Hero Tabungan Utama.
                if (primary != null)
                  _HeroGoalCard(
                    goal: primary,
                    onTap: () => _openDetail(primary),
                  ),
                const SizedBox(height: 20),
                // Tujuan Aktif.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.goalsActive,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (active.length > 3)
                      TextButton(
                        onPressed: () {},
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t.seeAll),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final g in active.take(3))
                  _GoalCard(
                    goal: g,
                    onTap: () => _openDetail(g),
                  ),
                // Tujuan Kadaluarsa.
                if (expired.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: t.goalsExpired,
                    expanded: _showExpired,
                    onTap: () =>
                        setState(() => _showExpired = !_showExpired),
                  ),
                  if (_showExpired)
                    for (final g in expired)
                      _GoalCard(
                        goal: g,
                        onTap: () => _openDetail(g),
                        expired: true,
                      ),
                ],
                // Tujuan Selesai.
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: t.goalsCompleted,
                    expanded: _showCompleted,
                    onTap: () =>
                        setState(() => _showCompleted = !_showCompleted),
                  ),
                  if (_showCompleted)
                    for (final g in completed)
                      _GoalCard(
                        goal: g,
                        onTap: () => _openDetail(g),
                        completed: true,
                      ),
                ],
                const SizedBox(height: 20),
                // Buat Tujuan Baru.
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(LucideIcons.plus),
                    label: Text(t.createGoal),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Hero Tabungan Utama ala mockup.
class _HeroGoalCard extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback onTap;

  const _HeroGoalCard({
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pct = (goal.progress * 100).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.primarySavings,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(goal.saved),
                      style: DuitQuTheme.amountStyle(context, 28),
                    ),
                    Text(
                      t.fromTarget(formatRupiah(goal.target)),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: goal.progress,
                              minHeight: 10,
                              backgroundColor:
                                  scheme.surfaceContainerHighest,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                Color(0xFF27AE60),
                              ),
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
                    if (goal.deadline != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.targetDate(
                              formatTanggal(goal.deadline!, t),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Image.asset(
                'assets/mascot/goals/saving_hero.webp',
                width: 110,
                height: 110,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu tujuan ala mockup.
class _GoalCard extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback onTap;
  final bool expired;
  final bool completed;

  const _GoalCard({
    required this.goal,
    required this.onTap,
    this.expired = false,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pct = (goal.progress * 100).round();
    final color = Color(goal.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        goal.category.iconAsset,
                        width: 32,
                        height: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.goalProgress(
                            formatRupiah(goal.saved),
                            formatRupiah(goal.target),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (completed)
                    _Badge(
                      icon: LucideIcons.checkCircle,
                      label: t.completedLabel,
                      color: const Color(0xFF27AE60),
                    )
                  else if (expired)
                    _Badge(
                      icon: LucideIcons.clock,
                      label: t.expiredLabel,
                      color: const Color(0xFFEB5757),
                    )
                  else if (goal.deadline != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t.shortMonthYear(goal.deadline!),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 8,
                        backgroundColor:
                            scheme.surfaceContainerHighest,
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
              if (expired && goal.deadline != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 14,
                      color: Color(0xFFEB5757),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.expiredInfo(
                        formatTanggal(goal.deadline!, t),
                        _lateText(goal.deadline!, t),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEB5757),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "Terlambat 10 bulan" / "Terlambat 2 hari" — adaptif.
  String _lateText(DateTime deadline, AppLocalizations t) {
    final now = DateTime.now();
    final days = now.difference(deadline).inDays;
    if (days < 30) return t.lateDays(days);
    if (days < 365) return t.lateMonths(days ~/ 30);
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    return t.lateYearsMonths(years, months);
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Header section collapsible.
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              expanded
                  ? LucideIcons.chevronUp
                  : LucideIcons.chevronDown,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state: hero dengan maskot.
class _EmptyGoals extends StatelessWidget {
  final AppLocalizations t;
  final VoidCallback onCreate;

  const _EmptyGoals({
    required this.t,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/mascot/goals/saving_hero.webp',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              t.goalsEmptyTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.goalsEmptySubtitle,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(LucideIcons.plus),
                label: Text(t.createGoal),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
