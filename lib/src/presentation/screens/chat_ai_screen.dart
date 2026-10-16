import 'package:flutter/material.dart';

import '../../domain/entities/transaction.dart' as domain;
import '../chat/chat_controller.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../user_name_store.dart';
import '../widgets/chat_message_widgets.dart';
import '../widgets/mascot_image.dart';

/// Halaman penuh "DuitQu AI" (mockup panel kanan): header dengan tombol back,
/// sapaan maskot + chip aksi cepat, riwayat chat ala messenger, dan input bar.
/// Berbagi [ChatAssistantController] dengan bottom sheet — riwayat chat
/// dilanjutkan, bukan diulang dari awal.
class ChatAiScreen extends StatefulWidget {
  final ChatAssistantController controller;
  final UserNameStore nameStore;

  const ChatAiScreen({
    super.key,
    required this.controller,
    required this.nameStore,
  });

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen>
    with SingleTickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();
  late final AnimationController _wave;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    widget.controller.addListener(_onChatChanged);
    // Mulai dari bawah bila riwayat sudah ada (lanjutan dari sheet).
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChatChanged);
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _jumpToBottom() {
    if (!_scrollCtrl.hasClients || !mounted) return;
    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients || !mounted) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _submit() {
    final t = AppLocalizations.of(context);
    final text = _textCtrl.text;
    _textCtrl.clear();
    widget.controller.submit(text, t: t);
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

  void _stopListening() {
    _wave.stop();
    setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(t),
                Expanded(child: _content(t)),
                _inputBar(t),
              ],
            ),
            if (_listening)
              ListeningOverlay(wave: _wave, onDismiss: _stopListening),
          ],
        ),
      ),
    );
  }

  /// Header: back, avatar maskot, "DuitQu AI" + "● Siap membantu", "...".
  Widget _header(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const MascotImage.avatar(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.aiTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DuitQuTheme.income,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.aiOnline,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: t.more,
            onSelected: (v) {
              if (v == 'clear') widget.controller.clear();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clear',
                child: Text(t.aiClearHistory),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _content(AppLocalizations t) {
    final msgs = widget.controller.messages;
    if (msgs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _welcomeBlock(t),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: msgs.length + (widget.controller.hasUserMessage ? 0 : 1),
      itemBuilder: (context, i) {
        // Chip aksi cepat tampil di atas riwayat sebelum ada pesan user.
        if (!widget.controller.hasUserMessage && i == 0) {
          return _welcomeBlock(t);
        }
        final msg = widget.controller.hasUserMessage
            ? msgs[i]
            : msgs[i - 1];
        return _buildMsg(msg, t);
      },
    );
  }

  /// Sapaan maskot + 4 chip aksi cepat (2x2).
  Widget _welcomeBlock(AppLocalizations t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MascotImage.success(size: 120),
        const SizedBox(height: 16),
        ValueListenableBuilder<String?>(
          valueListenable: widget.nameStore,
          builder: (_, name, _) => Text(
            t.aiGreeting(name),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.aiSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: [
            _actionChip(
              '\u{1F451}',
              t.aiChipRecordExpense,
              () => widget.controller
                  .quickAdd(domain.TransactionType.expense),
            ),
            _actionChip(
              '\u{2B07}',
              t.aiChipRecordIncome,
              () => widget.controller
                  .quickAdd(domain.TransactionType.income),
            ),
            _actionChip(
              '\u{1F4C4}',
              t.aiChipMonthlyReport,
              () => widget.controller.monthlyReport(t),
            ),
            _actionChip(
              '\u{1F3AF}',
              t.aiChipTopExpense,
              () => widget.controller.topExpense(t),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _actionChip(String emoji, String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMsg(ChatMsg msg, AppLocalizations t) {
    switch (msg.kind) {
      case MsgKind.user:
        return UserBubble(
          text: msg.text,
          occurredAt: msg.occurredAt,
          showMeta: true,
        );
      case MsgKind.confirm:
        return _ConfirmCard(msg: msg, controller: widget.controller);
      case MsgKind.assistant:
        return AssistantBubble(text: msg.text);
    }
  }

  /// Input bar: field rounded + mic + tombol kirim biru bulat.
  Widget _inputBar(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 8, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: t.aiInputHint,
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: _startListening,
              icon: Icon(
                Icons.mic_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ),
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
      ),
    );
  }
}

/// Kartu konfirmasi transaksi ala mockup halaman penuh: header (ikon + nama +
/// tipe·kategori + nominal berwarna), baris Tanggal/Akun/Kategori,
/// tombol Edit (outline) + Simpan (solid).
class _ConfirmCard extends StatelessWidget {
  final ChatMsg msg;
  final ChatAssistantController controller;

  const _ConfirmCard({required this.msg, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final parsed = msg.parsed!;
    final isIncome = parsed.transactionType == 'income';
    final isExpense = parsed.transactionType == 'expense';
    final typeLabel = isIncome
        ? t.quickIncome
        : isExpense
            ? t.quickExpense
            : t.transfer;
    const category = '—'; // parser belum deteksi kategori: jujur tampilkan '—'
    final amountColor =
        isIncome ? DuitQuTheme.income : DuitQuTheme.expense;
    final time = msg.occurredAt;
    final dateText =
        '${t.todayAt} ${time.hour}.${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: DuitQuTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: DuitQuTheme.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: DuitQuTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      Text(
                        category == '—' ? typeLabel : '$typeLabel · $category',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isExpense ? '− ' : isIncome ? '+ ' : ''}${formatRupiah(parsed.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isIncome || isExpense ? amountColor : scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            _metaRow(
              context,
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFFF59E0B),
              label: t.dateLabel,
              value: dateText,
            ),
            _metaRow(
              context,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: DuitQuTheme.primaryBlue,
              label: t.accountLabel,
              value: _displayAccount(msg.accountHint),
            ),
            _metaRow(
              context,
              icon: Icons.sell_outlined,
              iconColor: DuitQuTheme.income,
              label: t.categoryLabel,
              value: category,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        msg.done ? null : () => controller.editConfirm(msg),
                    child: Text(t.edit),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: msg.done
                        ? null
                        : () => controller.saveConfirm(msg, t),
                    child: Text(t.aiSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayAccount(String? hint) {
    if (hint == null || hint.isEmpty) return '—';
    return hint[0].toUpperCase() + hint.substring(1);
  }

  Widget _metaRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
