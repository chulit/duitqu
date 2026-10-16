import 'package:flutter/material.dart';

import '../../data/auto_record_settings_store.dart';
import '../../data/receipt_capture.dart';
import '../../domain/entities/transaction.dart' as domain;
import '../../domain/entities/transaction_candidate.dart';
import '../../domain/repositories/candidate_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/chat_correction_service.dart';
import '../../domain/services/financial_query_service.dart';
import '../../domain/services/receipt_scan_service.dart';
import '../../domain/services/transaction_parser.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'mascot_image.dart';

/// Hasil parse sederhana dari teks chat.
class QuickParse {
  final int amount;
  final String description;

  const QuickParse({required this.amount, required this.description});
}

/// Isi bottom sheet chat assistant: sapaan maskot, chip saran cepat,
/// riwayat chat (scroll), dan input bar. Dipakai di dalam
/// [DraggableScrollableSheet] — [scrollController] diteruskan dari sana
/// agar drag sheet dan scroll riwayat terkoordinasi.
///
/// Logika chat (parse, kartu konfirmasi, koreksi/hapus, tanya jawab,
/// scan struk) sama persis seperti layar chat sebelumnya.
class ChatAssistantSheet extends StatefulWidget {
  final ScrollController scrollController;
  final void Function(QuickParse parsed) onSave;
  final TransactionRepository? txRepo;
  final FinancialQueryService? queryService;
  final CandidateRepository? candidateRepo;

  const ChatAssistantSheet({
    super.key,
    required this.scrollController,
    required this.onSave,
    this.txRepo,
    this.queryService,
    this.candidateRepo,
  });

  @override
  State<ChatAssistantSheet> createState() => _ChatAssistantSheetState();
}

enum _MsgKind { assistant, user, confirm }

/// Satu entri riwayat chat.
class _ChatMsg {
  final _MsgKind kind;
  final String text;
  final QuickParse? parsed;
  final String? accountHint;
  final DateTime occurredAt;
  bool done = false; // kartu konfirmasi sudah dipakai (simpan/edit)

  _ChatMsg({
    required this.kind,
    this.text = '',
    this.parsed,
    this.accountHint,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();
}

/// Chip saran: (emoji, teks yang dikirim sebagai pesan).
const _suggestionChips = [
  ('\u2615', 'Beli kopi 28 ribu'),
  ('\u{1F6CD}\uFE0F', 'Makan siang 35k'),
  ('\u{1F697}', 'Isi bensin 200 ribu'),
  ('\u{1F3E0}', 'Bayar listrik 125k'),
  ('\u{1F45B}', 'Terima gaji 5 juta'),
];

class _ChatAssistantSheetState extends State<ChatAssistantSheet>
    with SingleTickerProviderStateMixin {
  final _msgs = <_ChatMsg>[];
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _wave;
  bool _listening = false;
  bool _scanning = false;

  bool get _showChips =>
      !_msgs.any((m) => m.kind == _MsgKind.user);

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _addMsg(_ChatMsg msg) {
    setState(() => _msgs.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = widget.scrollController;
      if (!c.hasClients || !mounted) return;
      c.animateTo(
        c.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _say(String text) =>
      _addMsg(_ChatMsg(kind: _MsgKind.assistant, text: text));

  /// Parse via TransactionParser deterministik.
  QuickParse? _parse(String text) {
    final parsed = TransactionParser().parseChat(text);
    final amount = parsed.amount;
    if (amount == null || amount <= 0) return null;
    var desc = parsed.merchant ?? AppLocalizations.of(context).chatNoteDefault;
    // Kapitalisasi awal.
    desc = desc[0].toUpperCase() + desc.substring(1);
    return QuickParse(amount: amount, description: desc);
  }

  void _submitText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final t = AppLocalizations.of(context);
    _addMsg(_ChatMsg(kind: _MsgKind.user, text: text));
    _process(text, t);
  }

  void _submit() => _submitText(_ctrl.text);

  Future<void> _process(String text, AppLocalizations t) async {
    // 0. Cek pertanyaan keuangan dulu (tiket 08) — jawaban jadi bubble chat.
    final query = widget.queryService?.interpret(text);
    if (query != null) {
      final ans = await widget.queryService!.answer(query);
      if (!mounted) return;
      _say(ans);
      return;
    }
    // 1. Cek perintah koreksi/hapus dulu (tiket 07).
    final correction = ChatCorrectionService().interpret(
      text,
      (s) => TransactionParser().parseChat(s).amount,
    );
    if (correction != null && widget.txRepo != null) {
      await _handleCorrection(correction);
      return;
    }
    // 2. Fallback: parse transaksi baru.
    final raw = TransactionParser().parseChat(text);
    final parsed = _parse(text);
    if (parsed == null) {
      _say(t.chatParseFail);
      return;
    }
    _say(t.chatParsedOk);
    _addMsg(_ChatMsg(
      kind: _MsgKind.confirm,
      parsed: parsed,
      accountHint: raw.accountName,
      occurredAt: DateTime.now(),
    ));
  }

  Future<void> _handleCorrection(CorrectionCommand cmd) async {
    final repo = widget.txRepo!;
    final t = AppLocalizations.of(context);
    final recent = await repo.list(const TransactionQuery());
    final target = ChatCorrectionService().resolveTarget(cmd, recent);
    if (!mounted) return;

    if (target == null) {
      _say(t.correctionNotFound);
      return;
    }

    if (cmd.action == CorrectionAction.delete) {
      // Hapus wajib konfirmasi eksplisit.
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(t.confirmDeleteTitle),
          content: Text(t.confirmDeleteBody(
            target.merchant ?? t.unknownMerchant,
            target.amount,
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.deleteAction),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await repo.delete(target.id!);
        if (!mounted) return;
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
    if (!mounted) return;
    _say(t.corrected);
  }

  /// Tombol "Simpan Transaksi": buka form tambah (via onSave), lalu bubble sukses.
  void _saveConfirm(_ChatMsg msg) {
    final t = AppLocalizations.of(context);
    setState(() => msg.done = true);
    widget.onSave(msg.parsed!);
    _say(t.chatSaved);
    _say(t.chatSavedAsk);
  }

  /// Tombol "Edit" / baris info: buka form yang sama tanpa bubble sukses.
  void _editConfirm(_ChatMsg msg) {
    setState(() => msg.done = true);
    widget.onSave(msg.parsed!);
  }

  void _startListening() {
    setState(() => _listening = true);
    _wave.repeat(reverse: true);
    // Simulasi UI: kembali setelah 2 detik (tanpa STT beneran).
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _listening) {
        _wave.stop();
        setState(() => _listening = false);
      }
    });
  }

  /// Scan struk via kamera → kandidat (tiket 13).
  Future<void> _scanReceipt() async {
    final repo = widget.candidateRepo;
    if (repo == null || _scanning) return;
    final t = AppLocalizations.of(context);
    setState(() => _scanning = true);
    _say(t.receiptScanning);
    try {
      final service = ReceiptScanService(
        repo,
        capture: ReceiptCapture().captureAndRecognize,
      );
      final settings = await AutoRecordSettingsStore().load();
      final outcome = await service.scan(settings);
      if (!mounted) return;
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
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Handle draggable.
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Header: maskot + judul + deskripsi.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    const MascotImage.avatar(size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.chatSheetTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.chatSheetSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Riwayat chat (scrollable, controller dari sheet).
              Expanded(
                child: _msgs.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: _msgs.length,
                        itemBuilder: (context, i) => _buildMsg(_msgs[i], t),
                      ),
              ),
              // Chip saran cepat — hanya sebelum ada pesan user.
              if (_showChips) _suggestionChipsRow(t),
              _inputBar(t),
            ],
          ),
          if (_listening) _listeningOverlay(t),
        ],
      ),
    );
  }

  Widget _buildMsg(_ChatMsg msg, AppLocalizations t) {
    switch (msg.kind) {
      case _MsgKind.user:
        return _userBubble(msg.text);
      case _MsgKind.confirm:
        return _confirmCard(msg, t);
      case _MsgKind.assistant:
        return _assistantBubble(msg.text);
    }
  }

  Widget _assistantBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MascotImage.avatar(size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: DuitQuTheme.cardDecoration(context).copyWith(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(text, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(
                color: DuitQuTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu konfirmasi transaksi: judul + nominal + Edit,
  /// divider, baris Kategori/Akun/Tanggal, tombol Simpan Transaksi.
  Widget _confirmCard(_ChatMsg msg, AppLocalizations t) {
    final parsed = msg.parsed!;
    final scheme = Theme.of(context).colorScheme;
    final time = msg.occurredAt;
    final dateText =
        '${t.todayAt} ${time.hour}.${time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: DuitQuTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parsed.description,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(parsed.amount),
                        style: DuitQuTheme.amountStyle(context, 18),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: msg.done ? null : () => _editConfirm(msg),
                  child: Text(
                    t.edit,
                    style: const TextStyle(color: DuitQuTheme.primaryBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            _infoRow(
              icon: Icons.restaurant_rounded,
              iconBg: const Color(0xFF22B07D),
              label: t.categoryLabel,
              value: '—',
              onTap: msg.done ? null : () => _editConfirm(msg),
            ),
            _infoRow(
              icon: Icons.account_balance_wallet_rounded,
              iconBg: DuitQuTheme.primaryBlue,
              label: t.accountLabel,
              value: _displayAccount(msg.accountHint),
              onTap: msg.done ? null : () => _editConfirm(msg),
            ),
            _infoRow(
              icon: Icons.calendar_month_rounded,
              iconBg: const Color(0xFFF59E0B),
              label: t.dateLabel,
              value: dateText,
              onTap: msg.done ? null : () => _editConfirm(msg),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: msg.done ? null : () => _saveConfirm(msg),
                style: FilledButton.styleFrom(
                  disabledBackgroundColor:
                      scheme.primary.withValues(alpha: 0.4),
                ),
                child: Text(t.saveTransaction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilkan hint akun apa adanya, hanya kapitalisasi awal
  /// (data asli tidak diubah).
  String _displayAccount(String? hint) {
    if (hint == null || hint.isEmpty) return '—';
    return hint[0].toUpperCase() + hint.substring(1);
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconBg,
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconBg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Chip saran cepat (wrap, ~2 baris). Tap = langsung kirim sebagai pesan.
  Widget _suggestionChipsRow(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (emoji, text) in _suggestionChips)
            ActionChip(
              label: Text('$emoji $text'),
              labelStyle: TextStyle(
                fontSize: 13,
                color: scheme.onSurface,
              ),
              backgroundColor:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () => _submitText(text),
            ),
          ActionChip(
            label: Text(t.chatChipMore),
            labelStyle: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            backgroundColor: Colors.transparent,
            side: BorderSide(color: scheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () => _focus.requestFocus(),
          ),
        ],
      ),
    );
  }

  /// Input bar: avatar maskot, field, mic, kamera, tombol kirim biru.
  Widget _inputBar(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          const MascotImage.avatar(size: 40),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: t.chatSheetHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: t.scanReceipt,
            onPressed: widget.candidateRepo == null || _scanning
                ? null
                : _scanReceipt,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.camera_alt_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          IconButton(
            onPressed: _startListening,
            icon: Icon(
              Icons.mic_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _submit,
            style: IconButton.styleFrom(
              backgroundColor: DuitQuTheme.primaryBlue,
              foregroundColor: Colors.white,
              fixedSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  /// Overlay mendengarkan di dalam sheet.
  Widget _listeningOverlay(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          _wave.stop();
          setState(() => _listening = false);
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MascotImage.listening(size: 96),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _wave,
                    builder: (context, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 24; i++)
                          Container(
                            width: 4,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 2),
                            height: 8 +
                                28 *
                                    (0.5 +
                                        0.5 *
                                            ((_wave.value + i / 24) % 1.0 >
                                                    0.5
                                                ? 1.0
                                                : 0.2)),
                            decoration: BoxDecoration(
                              color: DuitQuTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.listeningTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.listeningHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
