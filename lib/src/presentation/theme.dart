import 'package:flutter/material.dart';

/// Tema DuitQu — arah "calm ledger": tenang dan tepercaya untuk aplikasi uang.
/// Hijau zamrud untuk pemasukan/saldo sehat, terakota (bukan merah menyala)
/// untuk pengeluaran.
class DuitQuTheme {
  static const emerald = Color(0xFF0E7C5B);
  static const terracotta = Color(0xFFC4552D);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          brightness: Brightness.light,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          brightness: Brightness.dark,
        ),
      );

  /// Warna nominal pemasukan — versi terang untuk mode gelap agar kontras.
  static Color incomeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF5ACB95)
          : emerald;

  /// Warna nominal pengeluaran — versi terang untuk mode gelap agar kontras.
  static Color expenseColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFEE9A6B)
          : terracotta;

  /// Gaya nominal: angka tabular agar mudah di-scan mata.
  static TextStyle amountStyle(
    BuildContext context,
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    final base = Theme.of(context).textTheme.titleLarge!;
    return base.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
