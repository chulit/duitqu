import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:duitqu/src/data/backup_service.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/sync_backend.dart';
import 'package:duitqu/src/data/sync_crypto.dart';
import 'package:duitqu/src/data/repositories/drift_account_repository.dart';
import 'package:duitqu/src/domain/entities/account.dart';
import 'package:duitqu/src/presentation/screens/sync_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend palsu: simpan di memori.
class FakeSyncBackend implements SyncBackend {
  bool connected = false;
  final blobs = <String, Uint8List>{};
  int _seq = 0;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Future<bool> connect() async {
    connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async => connected = false;

  @override
  Future<CloudBackupInfo> upload(Uint8List blob, {String? name}) async {
    final n = name ?? defaultBackupName();
    blobs[n] = blob;
    return CloudBackupInfo(
      id: 'id-${_seq++}',
      name: n,
      sizeBytes: blob.length,
      modifiedTime: DateTime.now(),
    );
  }

  @override
  Future<List<CloudBackupInfo>> list() async => blobs.entries
      .map(
        (e) => CloudBackupInfo(
          id: e.key,
          name: e.key,
          sizeBytes: e.value.length,
          modifiedTime: DateTime.now(),
        ),
      )
      .toList();

  @override
  Future<Uint8List> download(String id) async => blobs[id]!;

  @override
  Future<void> delete(String id) async => blobs.remove(id);
}

void main() {
  test(
    'integrasi: export -> enkripsi -> upload -> download -> dekripsi -> impor',
    () async {
      final db = schema.AppDatabase(NativeDatabase.memory());
      final backup = BackupService(db);
      final backend = FakeSyncBackend();
      const pass = 'rahasia-aman-123';

      // Isi data dulu.
      await DriftAccountRepository(db)
          .save(const Account(name: 'Cash', type: AccountType.cash));

      // Export -> enkripsi -> upload.
      final csv = await backup.exportCsv();
      expect(csv, contains('Cash'));
      final blob = await SyncCrypto.encrypt(
        Uint8List.fromList(csv.codeUnits),
        pass,
      );
      expect(String.fromCharCodes(blob.sublist(0, 7)), 'DQSYNC1');
      final info = await backend.upload(blob);
      expect(info.sizeBytes, blob.length);

      // List -> download -> dekripsi -> impor ke DB kosong lain.
      final list = await backend.list();
      expect(list.length, 1);
      final downloaded = await backend.download(list.first.id);
      final clear = await SyncCrypto.decrypt(downloaded, pass);
      final db2 = schema.AppDatabase(NativeDatabase.memory());
      final report = await BackupService(db2)
          .importCsv(String.fromCharCodes(clear));
      expect(report.accounts, 1);

      // Passphrase salah -> gagal.
      await expectLater(
        SyncCrypto.decrypt(downloaded, 'salah-salah'),
        throwsA(isA<SyncCryptoException>()),
      );

      await db.close();
      await db2.close();
    },
  );

  testWidgets('sync screen: hubungkan google', (tester) async {
    final db = schema.AppDatabase(NativeDatabase.memory());
    final backend = FakeSyncBackend();

    await tester.pumpWidget(
      MaterialApp(
        home: SyncScreen(backup: BackupService(db), backend: backend),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum terhubung'), findsOneWidget);

    await tester.tap(find.text('Hubungkan Google'));
    await tester.pumpAndSettle();

    expect(find.text('Terhubung ke Google Drive'), findsOneWidget);
    expect(find.text('Backup Sekarang'), findsOneWidget);

    await db.close();
  });
}
