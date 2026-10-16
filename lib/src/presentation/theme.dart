import 'package:flutter/material.dart';

/// Tema DuitQu mengikuti mockup: biru friendly, kartu putih membulat,
/// latar abu-biru sangat muda.
class DuitQuTheme {
  DuitQuTheme._();

  static const double radius = 20;

  /// Biru utama (tombol, aksen, nav aktif). Sesuai mockup v2 (~#2E9BFF).
  static const Color primaryBlue = Color(0xFF2E9BFF);
  static const Color primaryDark = Color(0xFF1B5FC1);

  /// Latar aplikasi (mockup v2: putih/abu sangat muda).
  static const Color scaffoldBg = Color(0xFFF7FAFE);

  /// Teks.
  static const Color ink = Color(0xFF1B2A41);
  static const Color inkSoft = Color(0xFF6B7A90);

  /// Pemasukan / pengeluaran.
  static const Color income = Color(0xFF22B07D);
  static const Color expense = Color(0xFFE5484D);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      surface: Colors.white,
    );
    return _build(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: const Color(0xFF6EA8FE),
      surface: const Color(0xFF17202E),
    );
    return _build(scheme, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? scaffoldBg : const Color(0xFF0F1622),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: isLight ? ink : Colors.white,
        ),
        iconTheme: IconThemeData(color: isLight ? ink : Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        // Mockup v2: kartu putih dengan shadow halus.
        shadowColor: isLight
            ? const Color(0xFF2E9BFF).withValues(alpha: 0.10)
            : Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? const Color(0xFFF1F4F9)
            : Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textTheme: const TextTheme(
        // Angka tabular agar nominal tidak "bergoyang".
        bodyLarge: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        bodyMedium: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        titleLarge: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }

  /// Gaya angka keuangan: selalu tabular.
  static TextStyle amountStyle(
    BuildContext context,
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static Color incomeColor(BuildContext context) => income;
  static Color expenseColor(BuildContext context) => expense;

  /// Dekorasi kartu ala mockup v2: putih, rounded-2xl, shadow halus.
  static BoxDecoration cardDecoration(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: isLight
          ? [
              BoxShadow(
                color: primaryBlue.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
}
