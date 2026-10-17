import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/transaction.dart' as domain;
import '../../domain/entities/transaction_candidate.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Inbox Auto-Catat: daftar kandidat butuh konfirmasi (tiket 05, spec v2).
///
/// Tersambung ke [CandidateRepository]. Kandidat yang belum dikonfirmasi
/// TIDAK masuk total pemasukan/pengeluaran.
class InboxScreen extends StatefulWidget {
  final CandidateRepository candidateRepo;
  final TransactionRepository txRepo;

  const InboxScreen({
    super.key,
    required this.candidateRepo,
    required this.txRepo,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _showPending = true;
  List<TransactionCandidate> _candidates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.candidateRepo
        .listByStatus(CandidateStatus.needsReview);
    if (!mounted) return;
    setState(() {
      _candidates = list;
      _loading = false;
    });
  }

  /// Konfirmasi: simpan kandidat sebagai transaksi via TransactionRepository.
  Future<void> _confirm(TransactionCandidate c) async {
    final p = c.parsedPayload;
    final tx = domain.Transaction(
      type: domain.TransactionType.values.byName(
        (p['transaction_type'] as String? ?? 'expense').toLowerCase(),
      ),
      amount: (p['amount'] as num).toInt(),
      categoryId: p['category_id'] as int?,
      accountId: p['account_id'] as int,
      toAccountId: p['to_account_id'] as int?,
      merchant: p['merchant'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(
        (p['occurred_at'] as int?) ?? c.receivedAt.millisecondsSinceEpoch,
      ),
      note: p['description'] as String?,
      createdAt: DateTime.now(),
      origin: _toOrigin(c.sourceType),
      sourceCandidateId: c.id,
    );
    final txId = await widget.txRepo.save(tx);
    await widget.candidateRepo.update(
      c.copyWith(
        status: CandidateStatus.saved,
        transactionId: txId,
        processedAt: DateTime.now(),
      ),
    );
    await _load();
  }

  Future<void> _ignore(TransactionCandidate c) async {
    await widget.candidateRepo.update(
      c.copyWith(
        status: CandidateStatus.ignored,
        processedAt: DateTime.now(),
      ),
    );
    await _load();
  }

  Future<void> _markDuplicate(TransactionCandidate c) async {
    await widget.candidateRepo.update(
      c.copyWith(
        status: CandidateStatus.duplicate,
        processedAt: DateTime.now(),
      ),
    );
    await _load();
  }

  domain.TransactionOrigin _toOrigin(CandidateSourceType s) {
    switch (s) {
      case CandidateSourceType.manual:
        return domain.TransactionOrigin.manual;
      case CandidateSourceType.chat:
        return domain.TransactionOrigin.chat;
      case CandidateSourceType.androidNotification:
        return domain.TransactionOrigin.androidNotification;
      case CandidateSourceType.receiptScan:
        return domain.TransactionOrigin.receiptScan;
      case CandidateSourceType.statementImport:
        return domain.TransactionOrigin.statementImport;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pendingCount = _candidates.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(t.inboxTitle),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: const BoxDecoration(
                color: DuitQuTheme.expense,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                _Tab(
                  label: t.needsConfirmation,
                  count: pendingCount,
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _candidates.isEmpty
                    ? _EmptyState(t: t, scheme: scheme)
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        itemCount: _candidates.length,
                        itemBuilder: (_, i) {
                          final c = _candidates[i];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),
                            child: _CandidateCard(
                              candidate: c,
                              onConfirm: () => _confirm(c),
                              onIgnore: () => _ignore(c),
                              onDuplicate: () => _markDuplicate(c),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations t;
  final ColorScheme scheme;

  const _EmptyState({required this.t, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Center(
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
                LucideIcons.mailCheck,
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
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

/// Kartu satu kandidat butuh review.
class _CandidateCard extends StatelessWidget {
  final TransactionCandidate candidate;
  final VoidCallback onConfirm;
  final VoidCallback onIgnore;
  final VoidCallback onDuplicate;

  const _CandidateCard({
    required this.candidate,
    required this.onConfirm,
    required this.onIgnore,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = candidate.parsedPayload;
    final amount = (p['amount'] as num?)?.toInt() ?? 0;
    final merchant =
        (p['merchant'] as String?) ?? t.unknownMerchant;
    final type = (p['transaction_type'] as String? ?? 'expense')
        .toLowerCase();
    final isExpense = type != 'income';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isExpense
                            ? DuitQuTheme.expense
                            : DuitQuTheme.income)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _sourceIcon(candidate.sourceType),
                    color: isExpense
                        ? DuitQuTheme.expense
                        : DuitQuTheme.income,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _sourceLabel(candidate.sourceType, t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${isExpense ? '-' : '+'}${formatter.format(amount)}',
                        style: DuitQuTheme.amountStyle(context, 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(candidate.receivedAt, t),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (candidate.reviewReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: DuitQuTheme.expense.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.info,
                      size: 14,
                      color: DuitQuTheme.expense,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        candidate.reviewReason!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onIgnore,
                    child: Text(t.ignore),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDuplicate,
                    child: Text(t.markDuplicate),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
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

  IconData _sourceIcon(CandidateSourceType s) {
    switch (s) {
      case CandidateSourceType.manual:
        return LucideIcons.pencil;
      case CandidateSourceType.chat:
        return LucideIcons.messageCircle;
      case CandidateSourceType.androidNotification:
        return LucideIcons.bell;
      case CandidateSourceType.receiptScan:
        return LucideIcons.receipt;
      case CandidateSourceType.statementImport:
        return LucideIcons.fileUp;
    }
  }

  String _sourceLabel(CandidateSourceType s, AppLocalizations t) {
    switch (s) {
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

  String _timeAgo(DateTime dt, AppLocalizations t) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return t.justNow;
    if (diff.inMinutes < 60) return t.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return t.hoursAgo(diff.inHours);
    return t.daysAgo(diff.inDays);
  }
}
