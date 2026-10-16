import 'package:flutter/material.dart';

import '../../domain/entities/transaction.dart' as domain;
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/chat_correction_service.dart';
import '../../domain/services/financial_query_service.dart';
import '../../domain/services/transaction_parser.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/chat_sheet.dart' show QuickParse;
import '../widgets/mascot_image.dart';

/// Layar penuh chat assistant: parse transaksi baru, koreksi/hapus via chat,
/// dan tanya jawab keuangan — mengikuti alur [ChatSheet] persis, tapi dengan
/// riwayat bubble chat ala mockup v2.
class ChatAssistantScreen extends StatefulWidget {
  final void Function(QuickParse parsed) onSave;
  final TransactionRepository? txRepo;
  final FinancialQueryService? queryService;

  const ChatAssistantScreen({
    super.key,
    required this.onSave,
    this.txRepo,
    this.queryService,
  });

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
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

class _ChatAssistantScreenState extends State<ChatAssistantScreen>
    with SingleTickerProviderStateMixin {
  final _msgs = <_ChatMsg>[];
  final _scroll = ScrollController();
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _wave;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Sapaan awal — selalu ada, jadi tak perlu empty state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _addMsg(_ChatMsg(
        kind: _MsgKind.assistant,
        text: AppLocalizations.of(context).chatGreeting,
      ));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _ctrl.dispose();
    _focus.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _addMsg(_ChatMsg msg) {
    setState(() => _msgs.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || !mounted) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _say(String text) =>
      _addMsg(_ChatMsg(kind: _MsgKind.assistant, text: text));

  /// Parse via TransactionParser deterministik (sama seperti ChatSheet).
  QuickParse? _parse(String text) {
    final parsed = TransactionParser().parseChat(text);
    final amount = parsed.amount;
    if (amount == null || amount <= 0) return null;
    var desc = parsed.merchant ?? AppLocalizations.of(context).chatNoteDefault;
    // Kapitalisasi awal.
    desc = desc[0].toUpperCase() + desc.substring(1);
    return QuickParse(amount: amount, description: desc);
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final t = AppLocalizations.of(context);
    _addMsg(_ChatMsg(kind: _MsgKind.user, text: text));

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

  void _showExamples() {
    final t = AppLocalizations.of(context);
    final examples = [t.chatExample1, t.chatExample2, t.chatExample3];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                t.chatExamplesTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final ex in examples)
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: DuitQuTheme.primaryBlue,
                ),
                title: Text(ex),
                onTap: () {
                  Navigator.pop(context);
                  _ctrl.text = ex;
                  _focus.requestFocus();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const MascotImage.avatar(size: 40),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.chatAssistantTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22B07D),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t.online,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        backgroundColor: scheme.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _msgs.length,
                  itemBuilder: (context, i) => _buildMsg(_msgs[i], t),
                ),
              ),
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

  /// Kartu konfirmasi transaksi ala mockup: judul + nominal + Edit,
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

  /// Bottom input bar ala mockup: "+" outline, field + sparkles + mic,
  /// tombol send bulat biru.
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
          InkWell(
            onTap: _showExamples,
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: Icon(Icons.add_rounded, color: scheme.onSurface),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: t.chatInputHint,
                prefixIcon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: DuitQuTheme.primaryBlue,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.mic_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: _startListening,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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

  /// Overlay mendengarkan: maskot + gelombang suara + hint.
  Widget _listeningOverlay(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        _wave.stop();
        setState(() => _listening = false);
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 8 +
                              28 *
                                  (0.5 +
                                      0.5 *
                                          ((_wave.value + i / 24) % 1.0 > 0.5
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
    );
  }
}
