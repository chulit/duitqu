import 'package:duitqu/src/domain/entities/transaction_candidate.dart';
import 'package:duitqu/src/domain/services/auto_record_policy.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionCandidate _candidate({
  Map<String, dynamic>? payload,
  double confidence = 0.9,
  CandidateSourceType sourceType = CandidateSourceType.androidNotification,
}) {
  return TransactionCandidate(
    sourceType: sourceType,
    parsedPayload: payload ??
        {
          'transaction_type': 'expense',
          'amount': 50000,
          'account_id': 1,
          'merchant': 'Indomaret',
        },
    confidence: confidence,
    receivedAt: DateTime(2026, 10, 16, 10, 0),
  );
}

void main() {
  final policy = AutoRecordPolicy();
  const settings = AutoRecordSettings();

  group('matriks keputusan', () {
    test('kandidat sempurna → autoSave', () {
      final r = policy.evaluate(_candidate(), settings);
      expect(r.decision, PolicyDecision.autoSave);
    });

    test('master switch mati → needsReview', () {
      final r = policy.evaluate(
        _candidate(),
        const AutoRecordSettings(enabled: false),
      );
      expect(r.decision, PolicyDecision.needsReview);
      expect(r.reason, isNotNull);
    });

    test('sumber tidak diizinkan → needsReview', () {
      final r = policy.evaluate(
        _candidate(sourceType: CandidateSourceType.receiptScan),
        settings,
      );
      expect(r.decision, PolicyDecision.needsReview);
    });

    test('tipe tidak dikenali → needsReview', () {
      final r = policy.evaluate(
        _candidate(payload: {
          'transaction_type': 'misteri',
          'amount': 50000,
          'account_id': 1,
        }),
        settings,
      );
      expect(r.decision, PolicyDecision.needsReview);
      expect(r.reason, contains('Tipe'));
    });

    test('nominal nol/negatif → needsReview', () {
      for (final amt in [0, -100]) {
        final r = policy.evaluate(
          _candidate(payload: {
            'transaction_type': 'expense',
            'amount': amt,
            'account_id': 1,
          }),
          settings,
        );
        expect(r.decision, PolicyDecision.needsReview);
      }
    });

    test('akun belum pasti → needsReview', () {
      final r = policy.evaluate(
        _candidate(payload: {
          'transaction_type': 'expense',
          'amount': 50000,
        }),
        settings,
      );
      expect(r.decision, PolicyDecision.needsReview);
      expect(r.reason, contains('Akun'));
    });

    test('duplikat → ignore', () {
      final r = policy.evaluate(
        _candidate(),
        settings,
        isDuplicate: true,
      );
      expect(r.decision, PolicyDecision.ignore);
    });

    test('indikasi gagal/refund/pending → ignore', () {
      for (final desc in [
        'Transfer GAGAL',
        'Refund GoPay',
        'pending settlement',
      ]) {
        final r = policy.evaluate(
          _candidate(payload: {
            'transaction_type': 'expense',
            'amount': 50000,
            'account_id': 1,
            'description': desc,
          }),
          settings,
        );
        expect(r.decision, PolicyDecision.ignore,
            reason: 'desc: $desc');
      }
    });

    test('confidence rendah → needsReview', () {
      final r = policy.evaluate(
        _candidate(confidence: 0.5),
        settings,
      );
      expect(r.decision, PolicyDecision.needsReview);
    });

    test('confidence pas threshold → autoSave', () {
      final r = policy.evaluate(
        _candidate(confidence: 0.8),
        settings,
      );
      expect(r.decision, PolicyDecision.autoSave);
    });
  });
}
