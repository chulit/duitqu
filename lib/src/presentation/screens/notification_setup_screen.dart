import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/notification_bridge.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Aplikasi umum yang mengirim notifikasi transaksi (untuk allowlist).
const Map<String, String> commonSourceApps = {
  'com.gojek.gopay': 'GoPay',
  'com.dana': 'DANA',
  'id.co.bri.brimo': 'BRImo',
  'com.bca': 'BCA mobile',
  'com.bni': 'BNI Mobile',
  'id.co.bankmandiri.livin': 'Livin Mandiri',
  'com.ovo': 'OVO',
  'com.shopee.id': 'Shopee',
  'com.tokopedia.tkpd': 'Tokopedia',
};

/// Alur setup auto-catat notifikasi (tiket 09, spec v2).
///
/// Langkah: penjelasan → izin Notification Access → pilih aplikasi →
/// selesai. Izin opt-in eksplisit, bisa dicabut kapan saja.
class NotificationSetupScreen extends StatefulWidget {
  const NotificationSetupScreen({super.key});

  @override
  State<NotificationSetupScreen> createState() =>
      _NotificationSetupScreenState();
}

class _NotificationSetupScreenState
    extends State<NotificationSetupScreen> {
  bool _granted = false;
  bool _loading = true;
  final Set<String> _selected = {};

  static const _kAllowed = 'notif_allowed_packages';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final granted = await NotificationBridge.isAccessGranted();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kAllowed) ?? [];
    if (!mounted) return;
    setState(() {
      _granted = granted;
      _selected.addAll(saved);
      _loading = false;
    });
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kAllowed, _selected.toList());
  }

  Future<void> _openSettings() async {
    await NotificationBridge.openAccessSettings();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.notifSetupTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ExplanationCard(t: t),
                const SizedBox(height: 16),
                _StepTile(
                  number: '1',
                  title: t.notifStepPermission,
                  subtitle: t.notifStepPermissionDesc,
                  done: _granted,
                  action: _granted
                      ? null
                      : FilledButton(
                          onPressed: _openSettings,
                          child: Text(t.openSettings),
                        ),
                ),
                const SizedBox(height: 8),
                _StepTile(
                  number: '2',
                  title: t.notifStepApps,
                  subtitle: t.notifStepAppsDesc,
                  done: _selected.isNotEmpty,
                ),
                ...commonSourceApps.entries.map((e) => CheckboxListTile(
                      title: Text(e.value),
                      subtitle: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      value: _selected.contains(e.key),
                      activeColor: DuitQuTheme.income,
                      onChanged: !_granted
                          ? null
                          : (v) async {
                              setState(() {
                                if (v == true) {
                                  _selected.add(e.key);
                                } else {
                                  _selected.remove(e.key);
                                }
                              });
                              await _saveSelection();
                            },
                    )),
                const SizedBox(height: 16),
                Text(
                  t.notifPrivacyNote,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final AppLocalizations t;

  const _ExplanationCard({required this.t});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: DuitQuTheme.primaryBlue.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: DuitQuTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  t.notifHowItWorks,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.notifExplanation),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final bool done;
  final Widget? action;

  const _StepTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.done,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done
                        ? DuitQuTheme.income.withValues(alpha: 0.15)
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: DuitQuTheme.income,
                          )
                        : Text(
                            number,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
