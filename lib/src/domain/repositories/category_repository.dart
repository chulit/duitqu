import '../entities/category.dart';

/// Seam untuk data kategori.
abstract class CategoryRepository {
  /// Kategori bawaan — read-only.
  Future<List<Category>> defaults();

  Future<int> save(Category category);

  /// Dilarang bila kategori dipakai transaksi — throw StateError
  /// dengan pesan yang jelas (bukan silent).
  Future<void> delete(int id);

  Future<List<Category>> list();
}
