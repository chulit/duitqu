import 'dart:typed_data';

/// Metadata satu file backup di cloud.
class CloudBackupInfo {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime modifiedTime;

  const CloudBackupInfo({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.modifiedTime,
  });
}

/// Penyimpanan cloud untuk blob backup terenkripsi.
///
/// Implementasi pertama: Google Drive appDataFolder ([DriveSyncBackend]).
/// Backend lain (mis. VPS) tinggal mengimplementasikan interface ini —
/// format blob enkripsi tidak berubah (lihat [SyncCrypto]).
abstract class SyncBackend {
  /// true bila user sudah login / terhubung.
  Future<bool> get isConnected;

  /// Tampilkan alur login. Mengembalikan true bila berhasil terhubung.
  Future<bool> connect();

  /// Putuskan koneksi (hapus token lokal).
  Future<void> disconnect();

  /// Upload [blob] terenkripsi. Nama file dibuat otomatis bila null.
  Future<CloudBackupInfo> upload(Uint8List blob, {String? name});

  /// Daftar backup yang tersedia, terbaru dulu.
  Future<List<CloudBackupInfo>> list();

  /// Unduh blob mentah berdasarkan [id].
  Future<Uint8List> download(String id);

  /// Hapus backup berdasarkan [id].
  Future<void> delete(String id);
}

/// Nama file default: duitqu-backup-YYYYMMDD-HHmmss.dqsync
String defaultBackupName([DateTime? when]) {
  final t = when ?? DateTime.now();
  String p(int n) => n.toString().padLeft(2, '0');
  return 'duitqu-backup-${t.year}${p(t.month)}${p(t.day)}-'
      '${p(t.hour)}${p(t.minute)}${p(t.second)}.dqsync';
}
