import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/notification_bridge.dart';
import 'package:duitqu/src/data/repositories/drift_candidate_repository.dart';
import 'package:duitqu/src/domain/entities/transaction_candidate.dart';
import 'package:duitqu/src/domain/services/auto_record_policy.dart';
import 'package:duitqu/src/domain/services/notification_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late schema.AppDatabase db;
  late DriftCandidateRepository candidateRepo;
  late NotificationPipeline pipeline;

  setUp(() {
    db = schema.AppDatabase(NativeDatabase.memory());
    candidateRepo = DriftCandidateRepository(db);
    pipeline = NotificationPipeline(candidateRepo);
  });

  tearDown(() => db.close());

  RawNotification notif({
    String package = 'com.gojek.gopay',
    String title = 'GoPay',
    String text = 'Pembayaran Rp35.000 di Kopi Kenangan berhasil',
  }) {
    return RawNotification(
      packageName: package,
      title: title,
      text: text,
      postedAt: DateTime(2026, 10, 16, 10, 5),
      id: 'notif-1',
    );
  }

  test('notifikasi transaksi → kandidat tersimpan', () async {
    final c = await pipeline.process(
      notif(),
      const AutoRecordSettings(),
    );
    expect(c, isNotNull);
    expect(c!.sourceType, CandidateSourceType.androidNotification);
    expect(c.sourceApp, 'com.gojek.gopay');
    expect(c.parsedPayload['amount'], 35000);
  });

  test('notifikasi tanpa nominal → diabaikan', () async {
    final c = await pipeline.process(
      notif(text: 'Promo menarik menantimu!'),
      const AutoRecordSettings(),
    );
    expect(c, isNull);
  });

  test('notifikasi sama dua kali → satu kandidat', () async {
    final n = notif();
    final c1 = await pipeline.process(n, const AutoRecordSettings());
    final c2 = await pipeline.process(n, const AutoRecordSettings());
    expect(c1!.id, c2!.id);

    final all = await candidateRepo
        .listByStatus(CandidateStatus.needsReview);
    // Bisa needsReview atau readyToSave tergantung policy; yang penting satu.
    final total = (await candidateRepo
            .listByStatus(CandidateStatus.readyToSave))
        .length +
        all.length;
    expect(total, 1);
  });
}
