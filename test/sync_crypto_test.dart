import 'dart:typed_data';

import 'package:duitqu/src/data/sync_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pass = 'rahasia-aman-123';
  final data = Uint8List.fromList(List.generate(256, (i) => i % 256));

  test('round-trip enkripsi -> dekripsi', () async {
    final blob = await SyncCrypto.encrypt(data, pass);
    expect(blob.length, greaterThan(data.length));
    // Magic header DQSYNC1
    expect(String.fromCharCodes(blob.sublist(0, 7)), 'DQSYNC1');
    final back = await SyncCrypto.decrypt(blob, pass);
    expect(back, data);
  });

  test('salt acak: dua enkripsi menghasilkan blob berbeda', () async {
    final a = await SyncCrypto.encrypt(data, pass);
    final b = await SyncCrypto.encrypt(data, pass);
    expect(a, isNot(equals(b)));
    // Keduanya tetap bisa dibuka.
    expect(await SyncCrypto.decrypt(a, pass), data);
    expect(await SyncCrypto.decrypt(b, pass), data);
  });

  test('passphrase salah -> gagal', () async {
    final blob = await SyncCrypto.encrypt(data, pass);
    expect(
      () => SyncCrypto.decrypt(blob, 'salah-salah-salah'),
      throwsA(isA<SyncCryptoException>()),
    );
  });

  test('ciphertext diutak-atik -> gagal', () async {
    final blob = await SyncCrypto.encrypt(data, pass);
    final tampered = Uint8List.fromList(blob);
    tampered[40] ^= 0xFF;
    expect(
      () => SyncCrypto.decrypt(tampered, pass),
      throwsA(isA<SyncCryptoException>()),
    );
  });

  test('bukan blob duitqu -> error format', () async {
    final junk = Uint8List.fromList(List.filled(64, 7));
    expect(
      () => SyncCrypto.decrypt(junk, pass),
      throwsA(predicate((e) => e is SyncCryptoException && e.code == 'format')),
    );
  });

  test('passphrase < 8 char ditolak saat enkripsi', () async {
    expect(
      () => SyncCrypto.encrypt(data, 'pendek'),
      throwsA(isA<SyncCryptoException>()),
    );
  });
}
