import '../entities/account.dart';

/// Seam untuk data akun.
abstract class AccountRepository {
  Future<int> save(Account account);

  /// Dilarang bila akun masih punya transaksi — throw StateError
  /// dengan pesan yang jelas (bukan silent).
  Future<void> delete(int id);

  Future<List<Account>> list();

  /// Saldo = initialBalance + pemasukan − pengeluaran ± transfer.
  /// [upTo] untuk saldo per titik waktu (opsional).
  Future<int> balance(int accountId, {DateTime? upTo});
}
