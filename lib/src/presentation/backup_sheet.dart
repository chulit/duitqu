import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Bottom sheet backup manual: ekspor / impor satu file CSV.
/// Dumb view — logika ekspor/impor dipegang pemanggil via callback.
class BackupSheet extends StatelessWidget {
  final VoidCallback onExport;
  final VoidCallback onImport;

  const BackupSheet({
    super.key,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(AppLocalizations.of(context).exportCsv),
            subtitle: Text(AppLocalizations.of(context).exportCsvSubtitle),
            onTap: () {
              Navigator.pop(context);
              onExport();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(AppLocalizations.of(context).importCsv),
            subtitle: Text(AppLocalizations.of(context).importCsvSubtitle),
            onTap: () {
              Navigator.pop(context);
              onImport();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
