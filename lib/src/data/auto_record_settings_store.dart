import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/transaction_candidate.dart';
import '../domain/services/auto_record_policy.dart';

/// Penyimpanan pengaturan auto-catat (tiket 04).
class AutoRecordSettingsStore {
  static const _kEnabled = 'auto_record_enabled';
  static const _kSources = 'auto_record_sources';
  static const _kThreshold = 'auto_record_threshold';

  Future<AutoRecordSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabled) ?? true;
    final threshold = prefs.getDouble(_kThreshold) ?? 0.8;
    final sourcesRaw = prefs.getStringList(_kSources);
    final sources = sourcesRaw == null
        ? const {
            CandidateSourceType.androidNotification,
            CandidateSourceType.chat,
          }
        : sourcesRaw
            .map((n) {
              try {
                return CandidateSourceType.values.byName(n);
              } catch (_) {
                return null;
              }
            })
            .whereType<CandidateSourceType>()
            .toSet();
    return AutoRecordSettings(
      enabled: enabled,
      allowedSources: sources,
      confidenceThreshold: threshold.clamp(0.0, 1.0),
    );
  }

  Future<void> save(AutoRecordSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, s.enabled);
    await prefs.setDouble(_kThreshold, s.confidenceThreshold);
    await prefs.setStringList(
      _kSources,
      s.allowedSources.map((e) => e.name).toList(),
    );
  }
}
