import 'dart:typed_data';

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

import 'sync_backend.dart';

/// Error koneksi/otorisasi sinkronisasi.
class SyncAuthException implements Exception {
  final String message;
  SyncAuthException(this.message);
  @override
  String toString() => 'SyncAuthException: $message';
}

/// Backend Google Drive `appDataFolder`.
///
/// Hanya memakai scope `drive.appdata` (non-sensitif): aplikasi hanya bisa
/// membaca/menulis data miliknya sendiri di folder khusus aplikasi — tidak
/// bisa melihat file Drive user yang lain.
///
/// Setup yang dibutuhkan (sekali, oleh pemilik aplikasi di Google Cloud Console):
/// 1. Enable Google Drive API.
/// 2. OAuth consent screen + scope `.../auth/drive.appdata`.
/// 3. OAuth client ID Android untuk `id.chulit.duitqu` (SHA-1 debug + release).
class DriveSyncBackend implements SyncBackend {
  static const _scopes = [drive.DriveApi.driveAppdataScope];

  /// Web OAuth client ID (opsional untuk Drive saja). Diisi via
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com`.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  auth.AuthClient? _client;
  drive.DriveApi? _drive;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialized = true;
  }

  /// Minta AuthClient dari [account]; [interactive] menentukan apakah boleh
  /// menampilkan UI bila scope belum diberikan.
  Future<auth.AuthClient?> _authClientFor(
    GoogleSignInAccount account, {
    required bool interactive,
  }) async {
    try {
      final authz = interactive
          ? await account.authorizationClient.authorizeScopes(_scopes)
          : await account.authorizationClient.authorizationForScopes(_scopes);
      return authz?.authClient(scopes: _scopes);
    } catch (e) {
      debugPrint('Otorisasi scope drive.appdata gagal: $e');
      return null;
    }
  }

  /// Coba dapatkan API via silent auth. Null bila butuh interaksi user.
  Future<drive.DriveApi?> _silentApi() async {
    await _ensureInitialized();
    final future = GoogleSignIn.instance.attemptLightweightAuthentication();
    if (future == null) return null; // platform mengandalkan stream
    final account = await future;
    if (account == null) return null;
    final client = await _authClientFor(account, interactive: false);
    if (client == null) return null;
    _client = client;
    return _drive = drive.DriveApi(client);
  }

  Future<drive.DriveApi> _api() async {
    if (_drive != null) return _drive!;
    final api = await _silentApi();
    if (api == null) {
      throw SyncAuthException(
        'Belum terhubung ke Google. Ketuk "Hubungkan Google".',
      );
    }
    return api;
  }

  /// Jalankan [fn], coba silent re-auth sekali bila 401/403.
  Future<T> _withRetry<T>(Future<T> Function(drive.DriveApi api) fn) async {
    try {
      return await fn(await _api());
    } on commons.DetailedApiRequestError catch (e) {
      if (e.status == 401 || e.status == 403) {
        _drive = null;
        _client?.close();
        _client = null;
        return await fn(await _api());
      }
      rethrow;
    }
  }

  @override
  Future<bool> get isConnected async => (await _silentApi()) != null;

  @override
  Future<bool> connect() async {
    await _ensureInitialized();
    late final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } catch (e) {
      debugPrint('Google sign-in dibatalkan/gagal: $e');
      return false;
    }
    final client = await _authClientFor(account, interactive: true);
    if (client == null) return false;
    _client = client;
    _drive = drive.DriveApi(client);
    return true;
  }

  @override
  Future<void> disconnect() async {
    _drive = null;
    _client?.close();
    _client = null;
    await GoogleSignIn.instance.signOut();
  }

  @override
  Future<CloudBackupInfo> upload(Uint8List blob, {String? name}) async {
    final fileName = name ?? defaultBackupName();
    return _withRetry((api) async {
      // Cari file dengan nama sama → update (hindari duplikat).
      final existing = await api.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName' and trashed = false",
        $fields: 'files(id)',
      );
      final media = commons.Media(Stream.value(blob), blob.length);
      drive.File file;
      if (existing.files?.isNotEmpty == true) {
        final id = existing.files!.first.id!;
        file = await api.files.update(drive.File(), id, uploadMedia: media);
      } else {
        file = await api.files.create(
          drive.File(name: fileName, parents: ['appDataFolder']),
          uploadMedia: media,
        );
      }
      final meta = await api.files.get(
        file.id!,
        $fields: 'id, name, size, modifiedTime',
      ) as drive.File;
      return CloudBackupInfo(
        id: meta.id!,
        name: meta.name ?? fileName,
        sizeBytes: int.tryParse(meta.size ?? '') ?? blob.length,
        modifiedTime: meta.modifiedTime ?? DateTime.now(),
      );
    });
  }

  @override
  Future<List<CloudBackupInfo>> list() async {
    return _withRetry((api) async {
      final res = await api.files.list(
        spaces: 'appDataFolder',
        q: "name contains '.dqsync' and trashed = false",
        orderBy: 'modifiedTime desc',
        pageSize: 50,
        $fields: 'files(id, name, size, modifiedTime)',
      );
      return (res.files ?? [])
          .map(
            (f) => CloudBackupInfo(
              id: f.id!,
              name: f.name ?? '',
              sizeBytes: int.tryParse(f.size ?? '') ?? 0,
              modifiedTime: f.modifiedTime ?? DateTime.now(),
            ),
          )
          .toList();
    });
  }

  @override
  Future<Uint8List> download(String id) async {
    return _withRetry((api) async {
      final media = await api.files.get(
        id,
        downloadOptions: commons.DownloadOptions.fullMedia,
      ) as commons.Media;
      final bytes = await media.stream.fold<BytesBuilder>(
        BytesBuilder(),
        (b, chunk) => b..add(chunk),
      );
      return bytes.toBytes();
    });
  }

  @override
  Future<void> delete(String id) async {
    await _withRetry((api) => api.files.delete(id));
  }
}
