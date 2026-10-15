import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/backup_service.dart';
import '../../data/drive_sync_backend.dart';
import '../../data/sync_backend.dart';
import '../../data/sync_crypto.dart';

/// Sinkronisasi cloud: backup terenkripsi end-to-end ke Google Drive.
///
/// Yang diupload hanya ciphertext — passphrase tidak pernah disimpan,
/// Google tidak bisa membaca isi backup.
class SyncScreen extends StatefulWidget {
  final BackupService backup;
  final SyncBackend backend;

  SyncScreen({super.key, required this.backup, SyncBackend? backend})
    : backend = backend ?? DriveSyncBackend();

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool? _connected;
  bool _busy = false;
  String? _status;
  List<CloudBackupInfo> _cloud = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final connected = await widget.backend.isConnected;
      List<CloudBackupInfo> list = const [];
      if (connected) list = await widget.backend.list();
      if (!mounted) return;
      setState(() {
        _connected = connected;
        _cloud = list;
        _status = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _status = 'Gagal memeriksa koneksi: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final ok = await widget.backend.connect();
    if (!mounted) return;
    if (ok) {
      await _refresh();
    } else {
      setState(() {
        _busy = false;
        _status = 'Login dibatalkan.';
      });
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Putuskan Google?'),
        content: const Text(
          'Backup yang sudah ada di cloud tidak dihapus, hanya koneksi di HP ini yang diputus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.backend.disconnect();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _cloud = [];
    });
  }

  /// Dialog passphrase: mode backup (minta 2x) atau restore (1x).
  Future<String?> _askPassphrase({required bool confirm}) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(confirm ? 'Buat passphrase' : 'Masukkan passphrase'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Passphrase mengenkripsi backup. Lupa passphrase = backup tidak bisa dibuka. Minimal 8 karakter.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: c1,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Passphrase',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Minimal 8 karakter' : null,
              ),
              if (confirm) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: c2,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Ulangi passphrase',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v != c1.text ? 'Tidak sama' : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(c, c1.text);
              }
            },
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    c1.dispose();
    c2.dispose();
    return result;
  }

  Future<void> _backupNow() async {
    final pass = await _askPassphrase(confirm: true);
    if (pass == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Mengenkripsi & mengupload...';
    });
    try {
      // 1. Ekspor CSV via BackupService yang sudah ada.
      final csv = await widget.backup.exportCsv();
      // 2. Enkripsi.
      final blob = await SyncCrypto.encrypt(
        Uint8List.fromList(csv.codeUnits),
        pass,
      );
      // 3. Upload.
      final info = await widget.backend.upload(blob);
      if (!mounted) return;
      setState(() {
        _status = 'Backup tersimpan: ${info.name}';
      });
      await _refresh();
    } on SyncCryptoException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal enkripsi: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal upload: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(CloudBackupInfo info) async {
    final pass = await _askPassphrase(confirm: false);
    if (pass == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Mengunduh & mendekripsi...';
    });
    try {
      final blob = await widget.backend.download(info.id);
      final clear = await SyncCrypto.decrypt(blob, pass);
      final csv = String.fromCharCodes(clear);
      final report = await widget.backup.importCsv(csv);
      if (!mounted) return;
      setState(() {
        _status =
            'Pulih: ${report.imported} data masuk, '
            '${report.skipped.length} baris dilewati.';
      });
    } on SyncCryptoException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal: ${e.message}');
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'File rusak: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal pulihkan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sinkronisasi Cloud')),
      body: _busy && _connected == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _connected == true
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                              color: _connected == true
                                  ? scheme.primary
                                  : scheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _connected == true
                                    ? 'Terhubung ke Google Drive'
                                    : 'Belum terhubung',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Backup dienkripsi di HP sebelum diupload. '
                          'Google hanya menyimpan data acak yang tidak bisa dibaca.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        if (_connected != true)
                          FilledButton.icon(
                            onPressed: _busy ? null : _connect,
                            icon: const Icon(Icons.login),
                            label: const Text('Hubungkan Google'),
                          )
                        else
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _busy ? null : _backupNow,
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Text('Backup Sekarang'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _busy ? null : _disconnect,
                                child: const Text('Putuskan'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _status!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
                if (_connected == true) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Backup di cloud (${_cloud.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (_cloud.isEmpty && !_busy)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Belum ada backup di cloud.'),
                      ),
                    ),
                  for (final b in _cloud)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(
                          b.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${_fmtSize(b.sizeBytes)} • ${_fmtDate(b.modifiedTime)}',
                        ),
                        trailing: const Icon(Icons.cloud_download_outlined),
                        onTap: _busy ? null : () => _restore(b),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  String _fmtDate(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }
}
