import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Floating navbar ala mockup: 4 tab + pil chat AI di tengah.
class FloatingNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onChatTap;

  const FloatingNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final labels = [t.navHome, t.navInsight, t.navGoals, t.navMore];
    final icons = [
      Icons.home_rounded,
      Icons.bar_chart_rounded,
      Icons.flag_rounded,
      Icons.menu_rounded,
    ];
    // Tab 0,1 di kiri pil — tab 2,3 di kanan pil.
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: DuitQuTheme.primaryBlue.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            _NavItem(
              label: labels[i],
              icon: icons[i],
              active: currentIndex == i,
              onTap: () => onTap(i),
            ),
          Expanded(child: _ChatPill(onTap: onChatTap)),
          for (var i = 2; i < 4; i++)
            _NavItem(
              label: labels[i],
              icon: icons[i],
              active: currentIndex == i,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? DuitQuTheme.primaryBlue
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPill extends StatelessWidget {
  final VoidCallback onTap;

  const _ChatPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: DuitQuTheme.primaryBlue,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                t.chatHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            const Icon(
              Icons.mic_rounded,
              size: 18,
              color: DuitQuTheme.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}
