import 'package:flutter/material.dart';

import '../format.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Hasil parse sederhana dari teks chat.
class QuickParse {
  final int amount;
  final String description;

  const QuickParse({required this.amount, required this.description});
}

/// Bottom sheet chat ala mockup: default, ketik, dengar, hasil cepat.
/// UI saja — simpan membuka sheet tambah dengan prefill.
class ChatSheet extends StatefulWidget {
  final void Function(QuickParse parsed) onSave;

  const ChatSheet({super.key, required this.onSave});

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

enum _ChatState { idle, typing, listening, result }

class _ChatSheetState extends State<ChatSheet>
    with SingleTickerProviderStateMixin {
  _ChatState _state = _ChatState.idle;
  final _ctrl = TextEditingController();
  QuickParse? _parsed;
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Animasi hanya jalan saat mode mendengarkan (hemat + ramah test).
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _wave.dispose();
    super.dispose();
  }

  /// Parse heuristik: angka + ribu/juta, sisanya deskripsi.
  QuickParse? _parse(String text) {
    final lower = text.toLowerCase();
    final numMatch = RegExp(r'(\d[\d\.]*)').firstMatch(lower);
    if (numMatch == null) return null;
    var value = int.tryParse(numMatch.group(1)!.replaceAll('.', '')) ?? 0;
    if (lower.contains('juta') || lower.contains(' jt')) {
      value *= 1000000;
    } else if (lower.contains('ribu') ||
        lower.contains(' rb') ||
        lower.contains('rb')) {
      value *= 1000;
    }
    if (value <= 0) return null;
    var desc = text.replaceFirst(numMatch.group(0)!, '').trim();
    desc = desc
        .replaceAll(RegExp(r'\b(ribu|rb|juta|jt)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Hapus kata akun umum dari deskripsi.
    desc = desc
        .replaceAll(
          RegExp(r'\b(pakai|pake|dengan)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (desc.isEmpty) desc = 'Catatan';
    // Kapitalisasi awal.
    desc = desc[0].toUpperCase() + desc.substring(1);
    return QuickParse(amount: value, description: desc);
  }

  void _submit() {
    final parsed = _parse(_ctrl.text);
    if (parsed == null) return;
    setState(() {
      _parsed = parsed;
      _state = _ChatState.result;
    });
  }

  void _startListening() {
    setState(() => _state = _ChatState.listening);
    _wave.repeat(reverse: true);
    // Simulasi UI: kembali ke idle setelah 2 detik (tanpa STT beneran).
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _state == _ChatState.listening) {
        _wave.stop();
        setState(() => _state = _ChatState.idle);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (_state == _ChatState.listening)
              _listeningView(t)
            else ...[
              _inputRow(t),
              if (_state == _ChatState.result && _parsed != null) ...[
                const SizedBox(height: 12),
                _resultCard(t, _parsed!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _inputRow(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DuitQuTheme.primaryBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: DuitQuTheme.primaryBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (v) => setState(() {
              _state = v.isEmpty ? _ChatState.idle : _ChatState.typing;
            }),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: t.chatHintLong,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        if (_state == _ChatState.typing)
          IconButton.filled(
            icon: const Icon(Icons.send_rounded, size: 20),
            onPressed: _submit,
          )
        else
          IconButton(
            icon: Icon(Icons.mic_rounded, color: scheme.onSurfaceVariant),
            onPressed: _startListening,
          ),
      ],
    );
  }

  Widget _listeningView(AppLocalizations t) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 24; i++)
                Container(
                  width: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height:
                      8 +
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
        const SizedBox(height: 12),
        Text(t.listening, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _resultCard(AppLocalizations t, QuickParse parsed) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DuitQuTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: DuitQuTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.description,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  formatRupiah(parsed.amount),
                  style: DuitQuTheme.amountStyle(
                    context,
                    15,
                    color: DuitQuTheme.expenseColor(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            icon: const Icon(Icons.check_rounded),
            onPressed: () {
              Navigator.pop(context);
              widget.onSave(parsed);
            },
          ),
        ],
      ),
    );
  }
}
