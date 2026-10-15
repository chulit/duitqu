import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Error enkripsi/dekripsi sinkronisasi cloud.
class SyncCryptoException implements Exception {
  /// Kode mesin: 'format' | 'passphrase' | 'rusak'.
  final String code;
  final String message;
  SyncCryptoException(this.code, this.message);
  @override
  String toString() => 'SyncCryptoException($code): $message';
}

/// Enkripsi end-to-end untuk backup cloud.
///
/// Format blob: `DQSYNC1 | salt(16) | nonce(12) | ciphertext | tag(16)`.
/// - Kunci AES-256 diturunkan dari passphrase via PBKDF2-HMAC-SHA256.
/// - Salt acak per backup; nonce acak per enkripsi.
/// - Passphrase tidak pernah disimpan — lupa passphrase = tidak bisa dibuka.
class SyncCrypto {
  static const _magic = [0x44, 0x51, 0x53, 0x59, 0x4E, 0x43, 0x31]; // "DQSYNC1"
  static const _saltLen = 16;
  static const _nonceLen = 12;
  static const _iterations = 100000;

  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );
  static final _aes = AesGcm.with256bits();
  static final _random = Random.secure();

  static Uint8List _randBytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

  /// Enkripsi [plaintext] dengan [passphrase]. Mengembalikan blob siap upload.
  static Future<Uint8List> encrypt(
    Uint8List plaintext,
    String passphrase,
  ) async {
    if (passphrase.length < 8) {
      throw SyncCryptoException('passphrase', 'Passphrase minimal 8 karakter.');
    }
    final salt = _randBytes(_saltLen);
    final nonce = _randBytes(_nonceLen);
    final key = await _pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final box = await _aes.encrypt(plaintext, secretKey: key, nonce: nonce);
    final out = BytesBuilder()
      ..add(_magic)
      ..add(salt)
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  /// Dekripsi [blob] dengan [passphrase].
  ///
  /// Melempar [SyncCryptoException]:
  /// - `format`: bukan blob DuitQu yang valid,
  /// - `passphrase`: passphrase salah,
  /// - `rusak`: data rusak/diutak-atik.
  static Future<Uint8List> decrypt(Uint8List blob, String passphrase) async {
    final minLen = _magic.length + _saltLen + _nonceLen + 16;
    if (blob.length < minLen) {
      throw SyncCryptoException('format', 'Bukan file backup DuitQu.');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (blob[i] != _magic[i]) {
        throw SyncCryptoException('format', 'Bukan file backup DuitQu.');
      }
    }
    final salt = blob.sublist(_magic.length, _magic.length + _saltLen);
    final nonce = blob.sublist(
      _magic.length + _saltLen,
      _magic.length + _saltLen + _nonceLen,
    );
    final cipherText = blob.sublist(
      _magic.length + _saltLen + _nonceLen,
      blob.length - 16,
    );
    final tag = blob.sublist(blob.length - 16);
    final key = await _pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      // GCM gagal: passphrase salah ATAU data diutak-atik — tidak bisa dibedakan.
      throw SyncCryptoException(
        'passphrase',
        'Passphrase salah atau file rusak.',
      );
    }
  }
}
