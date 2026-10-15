/// Pengelompokan transaksi. Lihat GLOSSARY.md: Kategori.
class Category {
  final int? id;
  final String name;
  final String icon;
  final int color;
  /// True untuk kategori bawaan (read-only, tidak bisa dihapus/diubah).
  final bool isDefault;

  const Category({
    this.id,
    required this.name,
    this.icon = 'tag',
    this.color = 0xFF0E7C5B,
    this.isDefault = false,
  });
}
