import 'package:flutter/material.dart';

/// Maskot DuitQu (karakter biru hoodie) dari `assets/mascot/`.
///
/// Path sudah terdaftar di pubspec.yaml.
class MascotImage extends StatelessWidget {
  final String asset;
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;

  const MascotImage(
    this.asset, {
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  /// Hero home: maskot pegang koin Rp.
  const MascotImage.hero({super.key, this.size, this.width, this.height})
      : asset = 'assets/mascot/hero/hero.webp',
        fit = BoxFit.contain;

  /// Avatar lingkaran kecil (sapaan, chat).
  const MascotImage.avatar({super.key, this.size = 44})
      : asset = 'assets/mascot/expressions/hello.webp',
        width = null,
        height = null,
        fit = BoxFit.contain;

  /// Empty state: belum ada transaksi (maskot baca buku).
  const MascotImage.emptyTransactions({super.key, this.size})
      : asset = 'assets/mascot/poses/book.webp',
        width = null,
        height = null,
        fit = BoxFit.contain;

  /// Empty state: mendengarkan (maskot + mic).
  const MascotImage.listening({super.key, this.size})
      : asset = 'assets/mascot/expressions/curious.webp',
        width = null,
        height = null,
        fit = BoxFit.contain;

  /// Empty state: berhasil disimpan.
  const MascotImage.success({super.key, this.size})
      : asset = 'assets/mascot/poses/celebrate.webp',
        width = null,
        height = null,
        fit = BoxFit.contain;

  /// Empty state: buat tujuan (maskot + box).
  const MascotImage.goal({super.key, this.size})
      : asset = 'assets/mascot/stickers/box.webp',
        width = null,
        height = null,
        fit = BoxFit.contain;

  /// Kartu insight (maskot kasih tips).
  const MascotImage.tips({super.key, this.size, this.width, this.height})
      : asset = 'assets/mascot/poses/tips.webp',
        fit = BoxFit.contain;

  /// Hero home: maskot pegang koin Rp.
  const MascotImage.coin({super.key, this.size, this.width, this.height})
      : asset = 'assets/mascot/poses/coin.webp',
        fit = BoxFit.contain;

  /// Kartu CTA: maskot dengan lampu ide.
  const MascotImage.idea({super.key, this.size, this.width, this.height})
      : asset = 'assets/mascot/stickers/idea.webp',
        fit = BoxFit.contain;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    return Image.asset(
      asset,
      width: w,
      height: h,
      fit: fit,
      errorBuilder: (_, _, _) => Icon(
        Icons.pets_rounded,
        size: size ?? 48,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
