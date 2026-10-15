import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:duitqu/src/data/database.dart' as schema;
import 'package:duitqu/src/data/repositories/drift_category_repository.dart';
import 'package:duitqu/src/domain/entities/category.dart';
import 'package:flutter_test/flutter_test.dart';

schema.AppDatabase _openTestDb() =>
    schema.AppDatabase(NativeDatabase.memory());

Future<void> _addTxWithCategory(schema.AppDatabase db, int categoryId) {
  const epoch = 1760486400000; // 2026-10-15
  return db.into(db.transactions).insert(
        schema.TransactionsCompanion.insert(
          type: 'expense',
          amount: 25000,
          categoryId: Value(categoryId),
          accountId: 1,
          date: epoch,
          createdAt: epoch,
        ),
      );
}

void main() {
  late schema.AppDatabase db;
  late DriftCategoryRepository repo;

  setUp(() {
    db = _openTestDb();
    repo = DriftCategoryRepository(db);
  });

  tearDown(() => db.close());

  group('seed bawaan', () {
    test('seedDefaults mengisi 12 kategori', () async {
      await repo.seedDefaults();
      expect(await repo.defaults(), hasLength(12));
    });

    test('seedDefaults idempoten — tidak duplikat saat restart', () async {
      await repo.seedDefaults();
      await repo.seedDefaults();
      await repo.seedDefaults();
      expect(await repo.defaults(), hasLength(12));
      expect(await repo.list(), hasLength(12));
    });

    test('urutan dan nama sesuai daftar yang disetujui', () async {
      await repo.seedDefaults();
      final names = (await repo.defaults()).map((c) => c.name).toList();
      expect(names.first, 'Makan & Minum');
      expect(names.last, 'Lainnya');
      expect(names, contains('Biaya Admin'));
    });
  });

  group('kategori kustom', () {
    test('tambah kategori kustom', () async {
      await repo.seedDefaults();
      final id = await repo.save(
        const Category(name: 'Jajan Kopi', icon: 'coffee', color: 0xFF6F4E37),
      );

      final all = await repo.list();
      expect(all, hasLength(13));
      final added = all.singleWhere((c) => c.id == id);
      expect(added.isDefault, isFalse);
    });

    test('update kategori kustom', () async {
      final id = await repo.save(const Category(name: 'Kopi'));
      await repo.save(Category(id: id, name: 'Kopi Susu'));

      final all = await repo.list();
      expect(all.singleWhere((c) => c.id == id).name, 'Kopi Susu');
    });

    test('hapus kategori kustom yang tidak dipakai', () async {
      final id = await repo.save(const Category(name: 'Sementara'));
      await repo.delete(id);
      expect(
        (await repo.list()).where((c) => c.id == id),
        isEmpty,
      );
    });

    test('kategori bawaan tidak bisa dihapus/diubah', () async {
      await repo.seedDefaults();
      final first = (await repo.defaults()).first;

      expect(() => repo.delete(first.id!), throwsA(isA<StateError>()));
      expect(
        () => repo.save(Category(
            id: first.id!, name: 'Ubah', isDefault: true)),
        throwsA(isA<StateError>()),
      );
    });

    test('hapus kategori yang dipakai transaksi DITOLAK', () async {
      final id = await repo.save(const Category(name: 'Makan Siang'));
      await _addTxWithCategory(db, id);

      expect(
        () => repo.delete(id),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('masih dipakai 1 transaksi'),
        )),
      );
    });
  });
}
