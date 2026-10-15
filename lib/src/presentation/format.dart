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

/// Format tanggal Indonesia pendek. Contoh: 15 Okt 2026
String formatTanggal(DateTime d) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
}

/// Format bulan Indonesia panjang. Contoh: Oktober 2026
String formatBulan(DateTime d) {
  const bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  return '${bulan[d.month - 1]} ${d.year}';
}
