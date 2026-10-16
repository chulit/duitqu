import 'package:flutter/material.dart';

import '../chat/chat_controller.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'chat_message_widgets.dart';
import 'mascot_image.dart';

/// Isi bottom sheet chat assistant: sapaan maskot, chip saran cepat,
/// riwayat chat (scroll), dan input bar. Dipakai di dalam
/// [DraggableScrollableSheet] — [scrollController] diteruskan dari sana
/// agar drag sheet dan scroll riwayat terkoordinasi.
///
/// Berbagi [ChatAssistantController] dengan halaman penuh "DuitQu AI";
/// seluruh logika chat tinggal di controller, widget ini hanya render.
class ChatAssistantSheet extends StatefulWidget {
  final ScrollController scrollController;
  final ChatAssistantController controller;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  const ChatAssistantSheet({
    super.key,
    required this.scrollController,
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
    _wave.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
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
              // Header: maskot + judul + deskripsi + tombol expand.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
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
                    IconButton(
                      tooltip: t.expandChat,
                      onPressed: widget.onExpand,
                      icon: const Icon(Icons.open_in_full_rounded),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Riwayat chat (scrollable, controller dari sheet).
              Expanded(
                child: msgs.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: msgs.length,
                        itemBuilder: (context, i) => _buildMsg(msgs[i], t),
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

  /// Input bar: avatar maskot, field, kamera, mic, tombol kirim biru.
  /// Catatan: Scaffold sudah resize body saat keyboard terbuka
  /// (resizeToAvoidBottomInset), jadi tidak perlu tambah viewInsets manual
  /// — dulu sempat dobel dan menyisakan gap abu-abu di atas keyboard.
  Widget _inputBar(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
            onPressed: controller.candidateRepo == null || controller.scanning
                ? null
                : () => controller.scanReceipt(t: t),
            icon: controller.scanning
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
}
