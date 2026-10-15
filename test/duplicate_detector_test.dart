import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_candidate_repository.dart';
import 'package:duitqu/src/domain/entities/transaction_candidate.dart';
import 'package:duitqu/src/domain/services/duplicate_detector.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionCandidate _candidate({
  String? sourceReference,
  String? sourceApp,
  int amount = 35000,
  String merchant = 'Kopi Kenangan',
  DateTime? occurredAt,
  CandidateSourceType sourceType = CandidateSourceType.androidNotification,
}) {
  return TransactionCandidate(
    sourceType: sourceType,
    sourceApp: sourceApp,
    sourceReference: sourceReference,
    parsedPayload: {
      'transaction_type': 'expense',
      'amount': amount,
      'merchant': merchant,
      'occurred_at': (occurredAt ?? DateTime(2026, 10, 16, 10, 5))
          .millisecondsSinceEpoch,
    },
    receivedAt: DateTime(2026, 10, 16, 10, 5),
  );
}

void main() {
  final detector = DuplicateDetector();

  group('fingerprint', () {
    test('reference ID sama dari sumber sama → fingerprint sama', () {
      final a = _candidate(
        sourceApp: 'com.gojek.gopay',
        sourceReference: 'TXN-123',
      );
      final b = _candidate(
        sourceApp: 'com.gojek.gopay',
        sourceReference: 'TXN-123',
      );
      expect(detector.isDuplicate(a, b), isTrue);
    });

    test('reference beda → fingerprint beda', () {
      final a = _candidate(
        sourceApp: 'com.gojek.gopay',
        sourceReference: 'TXN-123',
      );
      final b = _candidate(
        sourceApp: 'com.gojek.gopay',
        sourceReference: 'TXN-456',
      );
      expect(detector.isDuplicate(a, b), isFalse);
    });

    test('tanpa reference: konten sama dalam bucket 10 menit → duplikat',
        () {
      final a = _candidate(occurredAt: DateTime(2026, 10, 16, 10, 2));
      final b = _candidate(occurredAt: DateTime(2026, 10, 16, 10, 8));
      expect(detector.isDuplicate(a, b), isTrue);
    });

    test('dua pembelian mirip beda jam → tetap beda', () {
      final a = _candidate(occurredAt: DateTime(2026, 10, 16, 10, 5));
      final b = _candidate(occurredAt: DateTime(2026, 10, 16, 15, 30));
      expect(detector.isDuplicate(a, b), isFalse);
    });

    test('nominal beda → fingerprint beda', () {
      final a = _candidate(amount: 35000);
      final b = _candidate(amount: 40000);
      expect(detector.isDuplicate(a, b), isFalse);
    });

    test('merchant case-insensitive dan spasi ternormalisasi', () {
      final a = _candidate(merchant: 'Kopi Kenangan');
      final b = _candidate(merchant: '  KOPI   kenangan ');
      expect(detector.isDuplicate(a, b), isTrue);
    });
  });

  group('idempotent save', () {
    late schema.AppDatabase db;
    late DriftCandidateRepository repo;

    setUp(() {
      db = schema.AppDatabase(NativeDatabase.memory());
      repo = DriftCandidateRepository(db);
    });

    tearDown(() => db.close());

    test('simpan dua kali → satu record', () async {
      final c = _candidate(
        sourceApp: 'com.gojek.gopay',
        sourceReference: 'TXN-789',
      );
      final id1 = await repo.save(c);
      final id2 = await repo.save(c);
      expect(id1, id2);

      final all =
          await repo.listByStatus(CandidateStatus.received);
      expect(all, hasLength(1));
    });

    test('fingerprint otomatis terisi saat save', () async {
      final id = await repo.save(_candidate());
      final got = await repo.getById(id);
      expect(got!.fingerprint, isNotNull);
      expect(got.fingerprint, isNotEmpty);
    });
  });
}
