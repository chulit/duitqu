import 'package:flutter/material.dart';

import '../chat/chat_controller.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'chat_message_widgets.dart';
import 'mascot_image.dart';

/// Isi bottom sheet chat assistant: sapaan maskot, chip saran cepat,
/// riwayat chat (scroll), dan input bar. Sheet ini ukurannya mengikuti
/// isi (compact seperti mockup) — bukan fractional seperti
/// DraggableScrollableSheet dulu.
///
/// Berbagi [ChatAssistantController] dengan halaman penuh "DuitQu AI";
/// seluruh logika chat tinggal di controller, widget ini hanya render.
class ChatAssistantSheet extends StatefulWidget {
  final ChatAssistantController controller;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  const ChatAssistantSheet({
    super.key,
    required this.controller,
    required this.onExpand,
    required this.onClose,
  });

  @override
  State<ChatAssistantSheet> createState() => _ChatAssistantSheetState();
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
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _listController = ScrollController();
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
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChatChanged);
    _ctrl.dispose();
    _focus.dispose();
    _listController.dispose();
    _wave.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _listController;
      if (!c.hasClients || !mounted) return;
      c.animateTo(
        c.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _submitText(String rawText) {
    final t = AppLocalizations.of(context);
    _ctrl.clear();
    widget.controller.submit(rawText, t: t);
  }

  void _submit() => _submitText(_ctrl.text);

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
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final msgs = controller.messages;
    final maxH = MediaQuery.of(context).size.height;
    return Container(
      // Compact mengikuti isi; full-width, sudut atas membulat,
      // sudut bawah siku agar nyambung flush ke navbar.
      constraints: BoxConstraints(maxHeight: maxH * 0.7),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle.
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              _header(t, scheme),
              // Riwayat chat: mengikuti isi, scroll bila melebihi batas.
              if (msgs.isNotEmpty)
                Flexible(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: maxH * 0.35),
                    child: ListView.builder(
                      controller: _listController,
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: msgs.length,
                      itemBuilder: (context, i) =>
                          _buildMsg(msgs[i], t),
                    ),
                  ),
                ),
              // Chip saran cepat — hanya sebelum ada pesan user.
              if (!controller.hasUserMessage) _suggestionChipsRow(t),
              _inputBar(t),
            ],
          ),
          if (_listening)
            ListeningOverlay(wave: _wave, onDismiss: _stopListening),
        ],
      ),
    );
  }

  /// Header: maskot + judul + deskripsi + tombol expand/close.
  Widget _header(AppLocalizations t, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MascotImage.avatar(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.chatSheetTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.chatSheetSubtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.expandChat,
            onPressed: widget.onExpand,
            icon: const Icon(Icons.open_in_full_rounded, size: 20),
          ),
          IconButton(
            tooltip:
                MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMsg(ChatMsg msg, AppLocalizations t) {
    switch (msg.kind) {
      case MsgKind.user:
        return UserBubble(text: msg.text);
      case MsgKind.confirm:
        return _confirmCard(msg, t);
      case MsgKind.assistant:
        return AssistantBubble(text: msg.text);
    }
  }

  /// Kartu konfirmasi transaksi: judul + nominal + Edit,
  /// divider, baris Kategori/Akun/Tanggal, tombol Simpan Transaksi.
  Widget _confirmCard(ChatMsg msg, AppLocalizations t) {
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
                  onPressed: msg.done
                      ? null
                      : () => widget.controller.editConfirm(msg),
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
              onTap: msg.done
                  ? null
                  : () => widget.controller.editConfirm(msg),
            ),
            _infoRow(
              icon: Icons.account_balance_wallet_rounded,
              iconBg: DuitQuTheme.primaryBlue,
              label: t.accountLabel,
              value: _displayAccount(msg.accountHint),
              onTap: msg.done
                  ? null
                  : () => widget.controller.editConfirm(msg),
            ),
            _infoRow(
              icon: Icons.calendar_month_rounded,
              iconBg: const Color(0xFFF59E0B),
              label: t.dateLabel,
              value: dateText,
              onTap: msg.done
                  ? null
                  : () => widget.controller.editConfirm(msg),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: msg.done
                    ? null
                    : () => widget.controller.saveConfirm(msg, t),
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
  /// Chip saran: pill biru muda, grid 3 kolom x 2 baris.
  Widget _suggestionChipsRow(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.6,
        children: [
          for (final (emoji, text) in _suggestionChips)
            _compactChip(
              scheme: scheme,
              label: '$emoji $text',
              onTap: () => _submitText(text),
            ),
          _compactChip(
            scheme: scheme,
            label: t.chatChipMore,
            italic: true,
            outlined: true,
            onTap: () => _focus.requestFocus(),
          ),
        ],
      ),
    );
  }

  /// Chip pill biru muda; teks mengecil bila kepanjangan.
  Widget _compactChip({
    required ColorScheme scheme,
    required String label,
    required VoidCallback onTap,
    bool italic = false,
    bool outlined = false,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: outlined
              ? Colors.transparent
              : isLight
                  ? const Color(0xFFEDF3FF)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: outlined
              ? Border.all(color: scheme.outlineVariant)
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 15,
              color: italic
                  ? scheme.onSurfaceVariant
                  : const Color(0xFF5B6B8C),
            ),
          ),
        ),
      ),
    );
  }

  /// Transaction composer: floating pill putih berisi maskot kecil,
  /// TextField multiline, tombol mic lingkaran, dan tombol kirim biru.
  Widget _inputBar(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: isLight
              ? Colors.white
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: const Color(0xFFD6E3FF).withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF347AFF).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: MascotImage.avatar(size: 40),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.send,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: t.chatSheetHint,
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 16,
                    height: 1.35,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _micButton(scheme, isLight),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _sendButton(),
            ),
          ],
        ),
      ),
    );
  }

  /// Tombol mic: lingkaran putih dengan border halus.
  Widget _micButton(ColorScheme scheme, bool isLight) {
    return InkWell(
      onTap: _startListening,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isLight ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.mic_rounded,
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
      ),
    );
  }

  /// Tombol kirim: lingkaran Frost Blue dengan ikon paper plane putih.
  Widget _sendButton() {
    return InkWell(
      onTap: _submit,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF347AFF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF347AFF).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
