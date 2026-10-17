/// Jenis akun. Lihat GLOSSARY.md: Akun.
enum AccountType { bank, cash, ewallet, other, creditCard }

/// Wadah uang. Pure Dart — tanpa dependensi framework/database.
class Account {
  final int? id;
  final String name;
  final AccountType type;
  /// Saldo awal dalam satuan terkecil mata uang (rupiah untuk IDR).
  final int initialBalance;
  final String icon;
  final int color;
  /// Nama bank (opsional, mis. "BCA (Bank Central Asia)").
  final String? bankName;
  /// Nomor rekening (opsional).
  final String? accountNumber;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0,
    this.icon = 'wallet',
    this.color = 0xFF0E7C5B,
    this.bankName,
    this.accountNumber,
  });
}
