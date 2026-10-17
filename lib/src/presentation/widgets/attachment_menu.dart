import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Menu lampiran bottom sheet: Scan struk / Upload foto / Pilih file.
/// Dipakai di panel chat (Home) dan full chat (DuitQu AI) — satu desain.
Future<void> showAttachmentMenu({
  required BuildContext context,
  required VoidCallback onScan,
  required VoidCallback onUploadPhoto,
  required VoidCallback onPickFile,
}) {
  final t = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _menuItem(
                  context,
                  icon: LucideIcons.scanLine,
                  iconBg: const Color(0xFF347AFF),
                  label: t.attachScan,
                  onTap: () {
                    Navigator.pop(ctx);
                    onScan();
                  },
                ),
                _menuItem(
                  context,
                  icon: LucideIcons.image,
                  iconBg: const Color(0xFF22B07D),
                  label: t.attachUploadPhoto,
                  onTap: () {
                    Navigator.pop(ctx);
                    onUploadPhoto();
                  },
                ),
                _menuItem(
                  context,
                  icon: LucideIcons.file,
                  iconBg: const Color(0xFFF59E0B),
                  label: t.attachPickFile,
                  onTap: () {
                    Navigator.pop(ctx);
                    onPickFile();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _menuItem(
  BuildContext context, {
  required IconData icon,
  required Color iconBg,
  required String label,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconBg, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
