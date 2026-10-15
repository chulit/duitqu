import 'package:drift/drift.dart';

import '../database.dart' as db;
import '../../domain/entities/transaction_candidate.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../../domain/services/duplicate_detector.dart';

/// Adapter drift untuk [CandidateRepository] (tiket 01, spec v2).
class DriftCandidateRepository implements CandidateRepository {
  final db.AppDatabase _db;

  DriftCandidateRepository(this._db);

  @override
  Future<int> save(TransactionCandidate c) async {
    // Idempoten (tiket 03): fingerprint sama → kembalikan id lama.
    final fp = DuplicateDetector().fingerprint(c);
    final existing = await findByFingerprint(fp);
    if (existing != null) return existing.id!;

    return _db
        .into(_db.transactionCandidates)
        .insert(
          db.TransactionCandidatesCompanion.insert(
            sourceType: c.sourceType.name,
            sourceApp: Value(c.sourceApp),
            sourceReference: Value(c.sourceReference),
            fingerprint: Value(c.fingerprint ?? fp),
            parsedPayload: Value(
              TransactionCandidate.encodePayload(c.parsedPayload),
            ),
            confidence: Value(c.confidence),
            status: Value(c.status.name),
            reviewReason: Value(c.reviewReason),
            transactionId: Value(c.transactionId),
            receivedAt: c.receivedAt.millisecondsSinceEpoch,
            processedAt: Value(c.processedAt?.millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<void> update(TransactionCandidate c) async {
    final id = c.id;
    if (id == null) throw StateError('Kandidat belum punya id.');
    await (_db.update(
      _db.transactionCandidates,
    )..where((t) => t.id.equals(id))).write(
      db.TransactionCandidatesCompanion(
        sourceType: Value(c.sourceType.name),
        sourceApp: Value(c.sourceApp),
        sourceReference: Value(c.sourceReference),
        fingerprint: Value(c.fingerprint),
        parsedPayload: Value(
          TransactionCandidate.encodePayload(c.parsedPayload),
        ),
        confidence: Value(c.confidence),
        status: Value(c.status.name),
        reviewReason: Value(c.reviewReason),
        transactionId: Value(c.transactionId),
        processedAt: Value(c.processedAt?.millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<TransactionCandidate?> getById(int id) async {
    final row = await (_db.select(
      _db.transactionCandidates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<TransactionCandidate>> listByStatus(
    CandidateStatus status,
  ) async {
    final rows =
        await (_db.select(_db.transactionCandidates)
              ..where((t) => t.status.equals(status.name))
              ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<TransactionCandidate?> findByFingerprint(String fingerprint) async {
    final row = await (_db.select(
      _db.transactionCandidates,
    )..where((t) => t.fingerprint.equals(fingerprint))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(
      _db.transactionCandidates,
    )..where((t) => t.id.equals(id))).go();
  }

  TransactionCandidate _toDomain(db.TransactionCandidate row) {
    return TransactionCandidate(
      id: row.id,
      sourceType: CandidateSourceType.values.byName(row.sourceType),
      sourceApp: row.sourceApp,
      sourceReference: row.sourceReference,
      fingerprint: row.fingerprint,
      parsedPayload: TransactionCandidate.decodePayload(row.parsedPayload),
      confidence: row.confidence,
      status: CandidateStatus.values.byName(row.status),
      reviewReason: row.reviewReason,
      transactionId: row.transactionId,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(row.receivedAt),
      processedAt: row.processedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.processedAt!),
    );
  }
}
