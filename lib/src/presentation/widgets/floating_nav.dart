import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Total footprint vertikal navbar dari bawah layar
/// (margin atas untuk tombol raised + tinggi container + margin bawah).
/// Dipakai AppShell agar bottom sheet chat diposisikan tepat di atas navbar.
const floatingNavFootprint = 114.0;
const _navHeight = 72.0;

/// Bottom nav ala mockup: Home, Insight, tombol chat raised di tengah,
/// Tujuan, Akun. Tombol tengah menonjol ke atas dengan kontur putih.
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
    final items = [
      // Label persis mockup (Home/Insight sama di ID & EN).
      _NavData('Home', Icons.home_rounded),
      _NavData(t.navInsight, Icons.bar_chart_rounded),
      _NavData(t.navGoals, Icons.flag_rounded),
      _NavData(t.navAccounts, Icons.person_rounded),
    ];
    return Container(
      // Margin atas memberi ruang untuk tombol tengah yang menonjol ke atas.
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            height: _navHeight,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
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
                    label: items[i].label,
                    icon: items[i].icon,
                    active: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                // Ruang untuk tombol chat raised di tengah.
                const SizedBox(width: 76),
                for (var i = 2; i < 4; i++)
                  _NavItem(
                    label: items[i].label,
                    icon: items[i].icon,
                    active: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
          // Tombol chat raised: kontur putih melengkung di belakang
          // lingkaran biru, menonjol ke atas navbar.
          Positioned(
            top: -18,
            left: 0,
            right: 0,
            child: Center(
              child: _ChatButton(onTap: onChatTap),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavData {
  final String label;
  final IconData icon;
  const _NavData(this.label, this.icon);
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol chat di tengah nav: lingkaran biru solid (tanpa gradient)
/// di atas kontur putih yang menonjol ke atas navbar.
class _ChatButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ChatButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF347AFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF347AFF).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
