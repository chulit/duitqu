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

/// Format Rupiah singkat untuk ruang sempit (chart).
/// Contoh: 4350000 -> "Rp 4,35 jt"; 783000 -> "Rp 783 rb"
String formatRupiahShort(int amount) {
  if (amount >= 1000000) {
    final v = amount / 1000000;
    var s = v.toStringAsFixed(2).replaceAll('.', ',');
    s = s.replaceAll(RegExp(r',?0+$'), '');
    return 'Rp $s jt';
  }
  if (amount >= 1000) {
    final v = amount / 1000;
    final s = v
        .toStringAsFixed(v == v.roundToDouble() ? 0 : 1)
        .replaceAll('.', ',');
    return 'Rp $s rb';
  }
  return formatRupiah(amount);
}
