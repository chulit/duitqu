import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/notification_bridge.dart';
import 'package:duitqu/src/data/repositories/drift_candidate_repository.dart';
import 'package:duitqu/src/domain/services/auto_record_policy.dart';
import 'package:duitqu/src/domain/services/notification_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// Benchmark performa pemrosesan notifikasi (tiket 12, spec v2).
///
/// Target: p95 < 2 detik untuk 50 notifikasi sederhana,
/// dan UI tetap responsif (tidak ada jank karena pemrosesan sync berat).
void main() {
  late schema.AppDatabase db;
  late NotificationPipeline pipeline;

  setUp(() {
    db = schema.AppDatabase(NativeDatabase.memory());
    pipeline = NotificationPipeline(DriftCandidateRepository(db));
  });

  tearDown(() => db.close());

  test('50 notifikasi: p95 di bawah 2 detik', () async {
    final latencies = <int>[];
    for (var i = 0; i < 50; i++) {
      final notif = RawNotification(
        packageName: 'com.gojek.gopay',
        title: 'GoPay',
        text: 'Pembayaran Rp${28000 + i * 1000} di Toko $i berhasil',
        postedAt: DateTime(2026, 10, 16, 10, i % 60),
        id: 'notif-$i',
      );
      final sw = Stopwatch()..start();
      await pipeline.process(notif, const AutoRecordSettings());
      sw.stop();
      latencies.add(sw.elapsedMilliseconds);
    }
    latencies.sort();
    final p95 = latencies[(latencies.length * 0.95).floor()];
    final max = latencies.last;
    // ignore: avoid_print
    print('Notification pipeline: p50=${latencies[25]}ms, '
        'p95=${p95}ms, max=${max}ms (n=50)');
    expect(p95, lessThan(2000));
  });
}
