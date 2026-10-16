import 'package:flutter/material.dart';

import '../../data/auto_record_settings_store.dart';
import '../../data/receipt_capture.dart';
import '../../domain/entities/transaction.dart' as domain;
import '../../domain/entities/transaction_candidate.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/chat_correction_service.dart';
import '../../domain/services/financial_query_service.dart';
import '../../domain/services/receipt_scan_service.dart';
import '../../domain/services/summary_service.dart';
import '../../domain/services/transaction_parser.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';

/// Hasil parse sederhana dari teks chat.
class QuickParse {
  final int amount;
  final String description;

  /// 'income' | 'expense' | 'transfer' (dari TransactionParser), null bila tak tahu.
  final String? transactionType;

  const QuickParse({
    required this.amount,
    required this.description,
    this.transactionType,
  });
}

enum MsgKind { assistant, user, confirm }

/// Satu entri riwayat chat.
class ChatMsg {
  final MsgKind kind;
  final String text;
  final QuickParse? parsed;
  final String? accountHint;
  final DateTime occurredAt;
  bool done = false; // kartu konfirmasi sudah dipakai (simpan/edit)

  ChatMsg({
    required this.kind,
    this.text = '',
    this.parsed,
    this.accountHint,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();
}

/// Controller chat assistant bersama: satu instance dipakai bottom sheet DAN
/// halaman penuh "DuitQu AI", sehingga riwayat chat dibagi — buka halaman
/// penuh melanjutkan isi sheet.
///
/// Seluruh logika chat (parse, kartu konfirmasi, koreksi/hapus, tanya jawab,
/// scan struk, laporan) tinggal di sini; widget hanya render state.
/// Controller bebas-BuildContext: string lokal dan dialog konfirmasi
/// disuntik dari widget via parameter/callback.
class ChatAssistantController extends ChangeNotifier {
  ChatAssistantController({
    required this.onSave,
    this.txRepo,
    this.queryService,
    this.candidateRepo,
    this.categoryRepo,
    this.onQuickAddType,
    this.onConfirmDelete,
    this._scanReceiptFn,
  });

  /// Buka form tambah dengan prefill hasil parse (dipakai tombol Simpan/Edit).
  final void Function(QuickParse parsed) onSave;

  /// Buka form tambah dengan tipe terpilih (chip "Catat pengeluaran/pemasukan").
  final void Function(domain.TransactionType type)? onQuickAddType;

  /// Dialog konfirmasi hapus; dipanggil dengan judul & isi yang sudah lokal.
  final Future<bool> Function(String title, String body)? onConfirmDelete;

  final TransactionRepository? txRepo;
  final FinancialQueryService? queryService;
  final CandidateRepository? candidateRepo;
  final CategoryRepository? categoryRepo;

  final Future<ReceiptScanOutcome> Function()? _scanReceiptFn;

  final List<ChatMsg> messages = [];
  bool scanning = false;

  bool get hasUserMessage => messages.any((m) => m.kind == MsgKind.user);

  void _addMsg(ChatMsg msg) {
    messages.add(msg);
    notifyListeners();
  }

  void _say(String text) => _addMsg(ChatMsg(kind: MsgKind.assistant, text: text));

  /// Bersihkan riwayat chat (hanya memori, tidak menyentuh data).
  void clear() {
    messages.clear();
    notifyListeners();
  }

  /// Parse via TransactionParser deterministik.
  QuickParse? _parse(String text, AppLocalizations t) {
    final parsed = TransactionParser().parseChat(text);
    final amount = parsed.amount;
    if (amount == null || amount <= 0) return null;
    var desc = parsed.merchant ?? t.chatNoteDefault;
    // Kapitalisasi awal.
    desc = desc[0].toUpperCase() + desc.substring(1);
    return QuickParse(
      amount: amount,
      description: desc,
      transactionType: parsed.transactionType,
    );
  }

  /// Kirim teks user dan proses: tanya jawab → koreksi/hapus → parse baru.
  Future<void> submit(String rawText, {required AppLocalizations t}) async {
    final text = rawText.trim();
    if (text.isEmpty) return;
    _addMsg(ChatMsg(kind: MsgKind.user, text: text));
    await _process(text, t);
  }

  Future<void> _process(String text, AppLocalizations t) async {
    // 0. Cek pertanyaan keuangan dulu (tiket 08) — jawaban jadi bubble chat.
    final query = queryService?.interpret(text);
    if (query != null) {
      final ans = await queryService!.answer(query);
      _say(ans);
      return;
    }
    // 1. Cek perintah koreksi/hapus dulu (tiket 07).
    final correction = ChatCorrectionService().interpret(
      text,
      (s) => TransactionParser().parseChat(s).amount,
    );
    if (correction != null && txRepo != null) {
      await _handleCorrection(correction, t);
      return;
    }
    // 2. Fallback: parse transaksi baru.
    final raw = TransactionParser().parseChat(text);
    final parsed = _parse(text, t);
    if (parsed == null) {
      _say(t.chatParseFail);
      return;
    }
    _say(t.chatParsedOk);
    _addMsg(ChatMsg(
      kind: MsgKind.confirm,
      parsed: parsed,
      accountHint: raw.accountName,
    ));
  }

  Future<void> _handleCorrection(
      CorrectionCommand cmd, AppLocalizations t) async {
    final repo = txRepo!;
    final recent = await repo.list(const TransactionQuery());
    final target = ChatCorrectionService().resolveTarget(cmd, recent);

    if (target == null) {
      _say(t.correctionNotFound);
      return;
    }

    if (cmd.action == CorrectionAction.delete) {
      // Hapus wajib konfirmasi eksplisit.
      final confirm = await onConfirmDelete?.call(
        t.confirmDeleteTitle,
        t.confirmDeleteBody(target.merchant ?? t.unknownMerchant, target.amount),
      );
      if (confirm == true) {
        await repo.delete(target.id!);
        _say(t.deleted);
      }
      return;
    }

    // Koreksi: update nominal transaksi yang ada.
    final updated = domain.Transaction(
      id: target.id,
      type: target.type,
      amount: cmd.newAmount ?? target.amount,
      categoryId: target.categoryId,
      accountId: target.accountId,
      toAccountId: target.toAccountId,
      merchant: target.merchant,
      date: target.date,
      note: target.note,
      createdAt: target.createdAt,
      items: target.items,
      origin: target.origin,
    );
    await repo.save(updated);
    _say(t.corrected);
  }

  /// Tombol "Simpan": buka form tambah (via onSave), lalu bubble sukses.
  void saveConfirm(ChatMsg msg, AppLocalizations t) {
    msg.done = true;
    onSave(msg.parsed!);
    _say(t.chatSaved);
    _say(t.chatSavedAsk);
    notifyListeners();
  }

  /// Tombol "Edit": buka form yang sama tanpa bubble sukses.
  void editConfirm(ChatMsg msg) {
    msg.done = true;
    onSave(msg.parsed!);
    notifyListeners();
  }

  /// Chip "Catat pengeluaran/pemasukan": buka form dengan tipe terpilih.
  void quickAdd(domain.TransactionType type) => onQuickAddType?.call(type);

  /// Chip "Laporan bulan ini": ringkasan pemasukan/pengeluaran/selisih.
  Future<void> monthlyReport(AppLocalizations t) async {
    final repo = txRepo;
    if (repo == null) return;
    _addMsg(ChatMsg(kind: MsgKind.user, text: '\u{1F4C4} ${t.aiChipMonthlyReport}'));
    final now = DateTime.now();
    final txs = await repo.list(TransactionQuery(
      dateFrom: DateTime(now.year, now.month, 1),
      dateTo: DateTime(now.year, now.month + 1, 1),
    ));
    const summary = SummaryService();
    final s = summary.summarize(txs);
    if (s.count == 0) {
      _say(t.aiNoData);
      return;
    }
    _say(t.aiMonthlyReport(
      formatRupiah(s.income),
      formatRupiah(s.expense),
      formatRupiah(s.income - s.expense),
    ));
  }

  /// Chip "Pengeluaran terbesar": kategori pengeluaran teratas bulan ini.
  Future<void> topExpense(AppLocalizations t) async {
    final repo = txRepo;
    if (repo == null) return;
    _addMsg(ChatMsg(kind: MsgKind.user, text: '\u{1F3AF} ${t.aiChipTopExpense}'));
    final now = DateTime.now();
    final txs = await repo.list(TransactionQuery(
      dateFrom: DateTime(now.year, now.month, 1),
      dateTo: DateTime(now.year, now.month + 1, 1),
    ));
    const summary = SummaryService();
    final byCat = summary.expenseByCategory(txs);
    if (byCat.isEmpty) {
      _say(t.aiNoData);
      return;
    }
    final top = byCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
    var name = '—';
    final cats = await categoryRepo?.list();
    if (cats != null) {
      for (final c in cats) {
        if (c.id == top.key) {
          name = c.name;
          break;
        }
      }
    }
    _say(t.aiTopExpense(name, formatRupiah(top.value)));
  }

  /// Scan struk via kamera → kandidat (tiket 13).
  Future<void> scanReceipt({required AppLocalizations t}) async {
    final repo = candidateRepo;
    if (repo == null || scanning) return;
    scanning = true;
    notifyListeners();
    _say(t.receiptScanning);
    try {
      final outcome = await (_scanReceiptFn ?? () => _defaultScan(repo))();
      if (outcome.cancelled) return;
      if (outcome.modelNotReady) {
        _say(t.receiptModelNotReady);
        return;
      }
      if (outcome.error != null || outcome.candidate == null) {
        _say(t.receiptFailed);
        return;
      }
      final c = outcome.candidate!;
      if (c.status == CandidateStatus.duplicate) {
        _say(t.receiptDuplicate);
        return;
      }
      final amount = c.parsedPayload['amount'];
      final formatted =
          amount is num ? 'Rp${amount.toInt()}' : 'nominal terbaca';
      _say(t.receiptToInbox(formatted));
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  Future<ReceiptScanOutcome> _defaultScan(CandidateRepository repo) async {
    final service = ReceiptScanService(
      repo,
      capture: ReceiptCapture().captureAndRecognize,
    );
    final settings = await AutoRecordSettingsStore().load();
    return service.scan(settings);
  }
}
