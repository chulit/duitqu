import 'package:flutter/material.dart';

import '../theme.dart';
import 'mascot_image.dart';

/// Empty state ala mockup v2: maskot + judul + subjudul + tombol aksi.
class EmptyState extends StatelessWidget {
  final MascotImage mascot;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const EmptyState({
    super.key,
    required this.mascot,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            mascot,
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartu insight dengan maskot (Insight & Tujuan).
class MascotTipCard extends StatelessWidget {
  final String message;
  final MascotImage mascot;

  const MascotTipCard({
    super.key,
    required this.message,
    this.mascot = const MascotImage.tips(size: 72),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DuitQuTheme.cardDecoration(context),
      child: Row(
        children: [
          mascot,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
