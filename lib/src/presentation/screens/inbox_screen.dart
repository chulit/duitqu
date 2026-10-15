import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Inbox Auto-Catat ala mockup. UI + empty state;
/// sumber data notifikasi dikerjakan di v4.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _showPending = true;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(t.inboxTitle),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: const BoxDecoration(
                color: DuitQuTheme.expense,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '0',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                _Tab(
                  label: t.needsConfirmation,
                  count: 0,
                  active: _showPending,
                  onTap: () => setState(() => _showPending = true),
                ),
                const SizedBox(width: 8),
                _Tab(
                  label: t.latest,
                  active: !_showPending,
                  onTap: () => setState(() => _showPending = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
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
                        Icons.mark_email_read_outlined,
                        size: 40,
                        color: DuitQuTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.inboxEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? DuitQuTheme.primaryBlue.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: active
              ? Border.all(
                  color: DuitQuTheme.primaryBlue.withValues(alpha: 0.4),
                )
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active
                    ? DuitQuTheme.primaryBlue
                    : scheme.onSurfaceVariant,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: const BoxDecoration(
                  color: DuitQuTheme.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartu satu entri inbox (dipakai saat v4 menyediakan data).
class InboxEntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final String time;
  final VoidCallback onIgnore;
  final VoidCallback onSave;

  const InboxEntryCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.time,
    required this.onIgnore,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(amount, style: DuitQuTheme.amountStyle(context, 14)),
                    ],
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onIgnore,
                    child: Text(t.ignore),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onSave,
                    child: Text(t.saveAction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
