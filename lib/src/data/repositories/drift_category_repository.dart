import 'package:drift/drift.dart';

import '../database.dart' as db;
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';

/// Kategori bawaan v1 (disetujui pengguna, grill ronde 2).
/// Nama ikon mengikuti konvensi nama Lucide (lihat Status Saver).
const List<Category> defaultCategories = [
  Category(name: 'Makan & Minum', icon: 'utensils', color: 0xFFC4552D, isDefault: true),
  Category(name: 'Transport', icon: 'car', color: 0xFF3E7CB1, isDefault: true),
  Category(name: 'Belanja', icon: 'shopping-bag', color: 0xFF7C5CBF, isDefault: true),
  Category(name: 'Tagihan', icon: 'receipt', color: 0xFFB8933E, isDefault: true),
  Category(name: 'Pulsa & Internet', icon: 'smartphone', color: 0xFF2D9CDB, isDefault: true),
  Category(name: 'Kesehatan', icon: 'heart-pulse', color: 0xFFE05260, isDefault: true),
  Category(name: 'Hiburan', icon: 'clapperboard', color: 0xFFD64570, isDefault: true),
  Category(name: 'Pendidikan', icon: 'graduation-cap', color: 0xFF3FA7A0, isDefault: true),
  Category(name: 'Gaji', icon: 'briefcase', color: 0xFF0E7C5B, isDefault: true),
  Category(name: 'Bonus', icon: 'gift', color: 0xFF5B8DEF, isDefault: true),
  Category(name: 'Biaya Admin', icon: 'landmark', color: 0xFF8A8F98, isDefault: true),
  Category(name: 'Lainnya', icon: 'shapes', color: 0xFF8A8F98, isDefault: true),
];

/// Adapter drift untuk [CategoryRepository].
class DriftCategoryRepository implements CategoryRepository {
  final db.AppDatabase _db;

  DriftCategoryRepository(this._db);

  /// Idempoten: aman dipanggil tiap app start, tidak akan duplikat.
  Future<void> seedDefaults() async {
    final existing = await (_db.select(_db.categories)
          ..where((t) => t.isDefault.equals(true)))
        .get();
    if (existing.isNotEmpty) return;

    await _db.batch((b) {
      for (final c in defaultCategories) {
        b.insert(
          _db.categories,
          db.CategoriesCompanion.insert(
            name: c.name,
            icon: Value(c.icon),
            color: Value(c.color),
            isDefault: const Value(true),
          ),
        );
      }
    });
  }

  @override
  Future<List<Category>> defaults() async {
    final rows = await (_db.select(_db.categories)
          ..where((t) => t.isDefault.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<int> save(Category category) async {
    if (category.isDefault) {
      throw StateError('Kategori bawaan tidak bisa diubah.');
    }
    if (category.id == null) {
      return _db.into(_db.categories).insert(
            db.CategoriesCompanion.insert(
              name: category.name,
              icon: Value(category.icon),
              color: Value(category.color),
              isDefault: const Value(false),
            ),
          );
    }
    await (_db.update(_db.categories)
          ..where((t) => t.id.equals(category.id!)))
        .write(
      db.CategoriesCompanion(
        name: Value(category.name),
        icon: Value(category.icon),
        color: Value(category.color),
      ),
    );
    return category.id!;
  }

  @override
  Future<void> delete(int id) async {
    final row = await (_db.select(_db.categories)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    if (row.isDefault) {
      throw StateError('Kategori bawaan tidak bisa dihapus.');
    }
    final used = await (_db.select(_db.transactions)
          ..where((t) => t.categoryId.equals(id)))
        .get();
    if (used.isNotEmpty) {
      throw StateError(
        'Kategori tidak bisa dihapus: masih dipakai ${used.length} transaksi.',
      );
    }
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<Category>> list() async {
    final rows = await (_db.select(_db.categories)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isDefault),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Category _toDomain(db.Category row) => Category(
        id: row.id,
        name: row.name,
        icon: row.icon,
        color: row.color,
        isDefault: row.isDefault,
      );
}
