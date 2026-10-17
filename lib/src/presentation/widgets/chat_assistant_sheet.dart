import 'package:flutter/material.dart';

import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../chat/chat_controller.dart';
import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'attachment_menu.dart';
import 'chat_message_widgets.dart';
import 'mascot_image.dart';
import 'scan_edit_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Ref repo untuk form edit scan.
class _AppRefs {
  final TransactionRepository txRepo;
  final CategoryRepository categoryRepo;
  final AccountRepository accountRepo;

  const _AppRefs({
    required this.txRepo,
    required this.categoryRepo,
    required this.accountRepo,
  });
}

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

  /// Dipanggil saat tap "Lihat transaksi" (navigasi ke detail).
  final void Function(Transaction? tx)? onViewTransaction;

  const ChatAssistantSheet({
    super.key,
    required this.controller,
    required this.onExpand,
    required this.onClose,
    this.onViewTransaction,
  });

  @override
  State<ChatAssistantSheet> createState() => _ChatAssistantSheetState();
}

class _ChatAssistantSheetState extends State<ChatAssistantSheet>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _listController = ScrollController();
  late final AnimationController _wave;
  bool _listening = false;
  // Offset drag vertikal untuk slide-down to dismiss.
  double _dragOffset = 0;

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

  /// Menu lampiran: scan struk / upload foto / pilih file.
  void _showAttachMenu(AppLocalizations t) {
    showAttachmentMenu(
      context: context,
      onScan: () => widget.controller.scanReceipt(t: t),
      onUploadPhoto: () =>
          widget.controller.scanReceipt(t: t, source: 'gallery'),
      onPickFile: () => widget.controller.scanReceipt(t: t, source: 'file'),
    );
  }

  /// Tombol Edit: form khusus untuk hasil scan, form biasa untuk teks.
  void _onEdit(ChatMsg msg) {
    if (msg.isScan) {
      final app = _appRefs;
      if (app == null) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => ScanEditSheet(
          msg: msg,
          txRepo: app.txRepo,
          categoryRepo: app.categoryRepo,
          accountRepo: app.accountRepo,
          onSaved: (savedTx) => widget.controller.markScanSaved(
            msg,
            AppLocalizations.of(context),
            savedTx,
          ),
        ),
      );
    } else {
      widget.controller.editConfirm(msg);
    }
  }

  /// Akses repo via ancestor AppShell (disuntik via controller).
  _AppRefs? get _appRefs {
    // Controller menyimpan repo; widget membaca dari sana.
    final c = widget.controller;
    if (c.txRepo == null ||
        c.categoryRepo == null ||
        c.accountRepo == null) {
      return null;
    }
    return _AppRefs(
      txRepo: c.txRepo!,
      categoryRepo: c.categoryRepo!,
      accountRepo: c.accountRepo!,
    );
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
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final msgs = controller.messages;
    final maxH = MediaQuery.of(context).size.height;
    return GestureDetector(
      // Slide ke bawah untuk tutup (pengganti tombol X).
      onVerticalDragUpdate: (details) {
        setState(() {
          _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, maxH);
        });
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragOffset > 120 || velocity > 500) {
          widget.onClose();
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Container(
      // Compact mengikuti isi; full-width, sudut atas membulat,
      // sudut bawah siku agar nyambung flush ke navbar.
      constraints: BoxConstraints(maxHeight: maxH * 0.7),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
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
        ),
      ),
    );
  }

  /// Header: maskot + judul + deskripsi + tombol expand.
  /// (Tombol close dihapus; tutup via slide ke bawah.)
  Widget _header(AppLocalizations t, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
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
                const SizedBox(height: 4),
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
            icon: const Icon(LucideIcons.maximize2, size: 20),
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
      case MsgKind.success:
        return _successCard(msg, t);
      case MsgKind.assistant:
        return AssistantBubble(text: msg.text);
    }
  }

  /// Kartu sukses setelah simpan: ringkasan + Lihat transaksi + Catat lagi.
  Widget _successCard(ChatMsg msg, AppLocalizations t) {
    final tx = msg.savedTx;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: DuitQuTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22B07D),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.savedSuccess,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (tx != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                tx.merchant ?? t.chatNoteDefault,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_smartDate(tx.date, t)} • ${formatRupiah(tx.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onViewTransaction?.call(tx),
                    icon: const Icon(LucideIcons.receipt, size: 18),
                    label: Text(t.viewTransaction),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _ctrl.clear();
                      _focus.requestFocus();
                    },
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: Text(t.recordAgain),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu konfirmasi transaksi: judul + nominal + Edit,
  /// divider, baris Kategori/Akun/Tanggal, tombol Simpan Transaksi.
  Widget _confirmCard(ChatMsg msg, AppLocalizations t) {
    final parsed = msg.parsed!;
    final scheme = Theme.of(context).colorScheme;
    final time = msg.occurredAt;
    final dateText = _smartDate(time, t);
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
                        // Pengeluaran pakai minus (keputusan desain).
                        '${parsed.transactionType == 'income' ? '' : '− '}${formatRupiah(parsed.amount)}',
                        style: DuitQuTheme.amountStyle(context, 18),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: msg.done
                      ? null
                      : () => _onEdit(msg),
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
              icon: LucideIcons.utensils,
              iconBg: const Color(0xFF22B07D),
              label: t.categoryLabel,
              value: msg.categoryName ?? '—',
              onTap: msg.done
                  ? null
                  : () => widget.controller.editConfirm(msg),
            ),
            _infoRow(
              icon: LucideIcons.wallet,
              iconBg: DuitQuTheme.primaryBlue,
              label: t.accountLabel,
              value: msg.accountName ?? _displayAccount(msg.accountHint),
              onTap: msg.done
                  ? null
                  : () => widget.controller.editConfirm(msg),
            ),
            _infoRow(
              icon: LucideIcons.calendarDays,
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

  /// Format tanggal cerdas: "Hari ini, 14.02" / "Kemarin, 14.02" /
  /// "16 Okt 2026, 14.02".
  String _smartDate(DateTime time, AppLocalizations t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    final hm =
        '${time.hour}.${time.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return '${t.todayAt} $hm';
    if (diff == 1) return '${t.yesterday}, $hm';
    return '${formatTanggal(time, t)}, $hm';
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
              LucideIcons.chevronRight,
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
    final chips = t.chatChips;
    Widget row(List<Widget> chips) => Row(
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: chips[i]),
            ],
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([
            for (final (emoji, text) in chips.take(3))
              _compactChip(
                scheme: scheme,
                label: '$emoji $text',
                onTap: () => _submitText(text),
              ),
          ]),
          const SizedBox(height: 8),
          row([
            for (final (emoji, text) in chips.skip(3))
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
          ]),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _circleButton(
                scheme: scheme,
                isLight: isLight,
                tooltip: t.attachScan,
                onTap: () => _showAttachMenu(t),
                icon: LucideIcons.plus,
              ),
            ),
            const SizedBox(width: 4),
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
  /// Tombol lingkaran outline (untuk + dan mic): gaya seragam 52px.
  Widget _circleButton({
    required ColorScheme scheme,
    required bool isLight,
    required String tooltip,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 52,
          height: 52,
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
            icon,
            color: scheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _micButton(ColorScheme scheme, bool isLight) {
    return _circleButton(
      scheme: scheme,
      isLight: isLight,
      tooltip: '',
      onTap: _startListening,
      icon: LucideIcons.mic,
    );
  }

  /// Tombol kirim: lingkaran Frost Blue dengan ikon paper plane putih.
  Widget _sendButton() {
    return InkWell(
      onTap: _submit,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 52,
        height: 52,
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
          LucideIcons.send,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
