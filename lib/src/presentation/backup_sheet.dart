import 'package:flutter/material.dart';

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
            title: const Text('Ekspor CSV'),
            subtitle: const Text('Simpan seluruh data ke satu file'),
            onTap: () {
              Navigator.pop(context);
              onExport();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Impor CSV'),
            subtitle: const Text('Pulihkan dari file backup'),
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
