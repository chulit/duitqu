import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'mascot_image.dart';

/// Bubble pesan asisten (kiri, dengan avatar maskot).
/// Dipakai bottom sheet dan halaman penuh "DuitQu AI".
class AssistantBubble extends StatelessWidget {
  final String text;

  const AssistantBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
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
}

/// Bubble pesan user (kanan, biru). [showMeta] menampilkan jam + centang
/// ganda ala mockup halaman penuh.
class UserBubble extends StatelessWidget {
  final String text;
  final DateTime? occurredAt;
  final bool showMeta;

  const UserBubble({
    super.key,
    required this.text,
    this.occurredAt,
    this.showMeta = false,
  });

  @override
  Widget build(BuildContext context) {
    final time = occurredAt;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  if (showMeta && time != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${time.hour}.${time.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay "mendengarkan" (simulasi UI) — dipakai di dalam Stack
/// bottom sheet maupun halaman penuh.
class ListeningOverlay extends StatelessWidget {
  final Animation<double> wave;
  final VoidCallback onDismiss;

  const ListeningOverlay({
    super.key,
    required this.wave,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          decoration: const BoxDecoration(color: Colors.black45),
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
                    animation: wave,
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
                                            ((wave.value + i / 24) % 1.0 > 0.5
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
