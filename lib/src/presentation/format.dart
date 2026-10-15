import 'l10n/app_localizations.dart';

/// Format Rupiah dengan pemisah ribuan titik, tanpa desimal.
/// Contoh: 1500000 -> "Rp 1.500.000"
String formatRupiah(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return 'Rp ${negative ? '-' : ''}$buf';
}

/// Format tanggal pendek sesuai locale. Contoh: 15 Okt 2026
String formatTanggal(DateTime d, AppLocalizations t) =>
    '${d.day} ${t.shortMonth(d.month)} ${d.year}';

/// Format bulan panjang sesuai locale. Contoh: Oktober 2026
String formatBulan(DateTime d, AppLocalizations t) =>
    '${t.longMonth(d.month)} ${d.year}';
