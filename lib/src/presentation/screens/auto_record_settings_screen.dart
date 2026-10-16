import 'package:flutter/material.dart';

import '../../data/auto_record_settings_store.dart';
import 'notification_setup_screen.dart';
import '../../domain/entities/transaction_candidate.dart';
import '../../domain/services/auto_record_policy.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Pengaturan kebijakan auto-catat (tiket 04, spec v2).
///
/// Menjelaskan kapan kandidat langsung disimpan vs masuk inbox review.
class AutoRecordSettingsScreen extends StatefulWidget {
  const AutoRecordSettingsScreen({super.key});

  @override
  State<AutoRecordSettingsScreen> createState() =>
      _AutoRecordSettingsScreenState();
}

class _AutoRecordSettingsScreenState
    extends State<AutoRecordSettingsScreen> {
  final _store = AutoRecordSettingsStore();
  AutoRecordSettings _settings = const AutoRecordSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _store.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _update(AutoRecordSettings s) async {
    setState(() => _settings = s);
    await _store.save(s);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.autoRecordSettings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ExplanationCard(t: t, scheme: scheme),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const NotificationSetupScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_outlined),
                  label: Text(t.notifSetupTitle),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(t.autoRecordEnabled),
                  subtitle: Text(t.autoRecordEnabledDesc),
                  value: _settings.enabled,
                  activeThumbColor: DuitQuTheme.income,
                  onChanged: (v) =>
                      _update(_settings.copyWith(enabled: v)),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    t.autoRecordSources,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final src in CandidateSourceType.values)
                  CheckboxListTile(
                    title: Text(_sourceLabel(src, t)),
                    value: _settings.allowedSources.contains(src),
                    activeColor: DuitQuTheme.income,
                    onChanged: _settings.enabled
                        ? (v) {
                            final next = Set<CandidateSourceType>.of(
                              _settings.allowedSources,
                            );
                            if (v == true) {
                              next.add(src);
                            } else {
                              next.remove(src);
                            }
                            _update(
                              _settings.copyWith(allowedSources: next),
                            );
                          }
                        : null,
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    t.confidenceThreshold(
                      (_settings.confidenceThreshold * 100).round(),
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Slider(
                  value: _settings.confidenceThreshold,
                  min: 0.5,
                  max: 1.0,
                  divisions: 10,
                  label:
                      '${(_settings.confidenceThreshold * 100).round()}%',
                  activeColor: DuitQuTheme.income,
                  onChanged: _settings.enabled
                      ? (v) => _update(
                            _settings.copyWith(confidenceThreshold: v),
                          )
                      : null,
                ),
                Text(
                  t.confidenceThresholdDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
    );
  }

  String _sourceLabel(CandidateSourceType src, AppLocalizations t) {
    switch (src) {
      case CandidateSourceType.manual:
        return t.sourceManual;
      case CandidateSourceType.chat:
        return t.sourceChat;
      case CandidateSourceType.androidNotification:
        return t.sourceNotification;
      case CandidateSourceType.receiptScan:
        return t.sourceReceipt;
      case CandidateSourceType.statementImport:
        return t.sourceStatement;
    }
  }
}

class _ExplanationCard extends StatelessWidget {
  final AppLocalizations t;
  final ColorScheme scheme;

  const _ExplanationCard({required this.t, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: DuitQuTheme.income.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_outlined,
                  color: DuitQuTheme.income,
                ),
                const SizedBox(width: 8),
                Text(
                  t.policyHowItWorks,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.policyExplanation),
          ],
        ),
      ),
    );
  }
}
