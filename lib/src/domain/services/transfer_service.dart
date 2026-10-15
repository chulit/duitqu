import '../entities/transaction.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';

/// Orkestrasi transfer antar akun + biaya admin otomatis.
///
/// Aturan (keputusan grill):
/// - Transfer adalah tipe tersendiri: TIDAK dihitung sebagai pengeluaran.
/// - Biaya admin (opsional) otomatis tercatat sebagai transaksi expense
///   berkategori "Biaya Admin" pada akun sumber, tanggal yang sama.
/// - Transaksi biaya admin adalah entitas mandiri: bisa dilihat/diubah/dihapus
///   sendiri di riwayat. Saat transfer di-edit, biaya yang sudah tercatat
///   tidak disentuh (tidak duplikat).
class TransferService {
  final TransactionRepository _txRepo;
  final CategoryRepository _categoryRepo;

  TransferService(this._txRepo, this._categoryRepo);

  /// Simpan transfer. [fee] opsional (>= 0).
  /// Mengembalikan id transaksi transfer.
  Future<int> saveTransfer(Transaction transfer, {int fee = 0}) async {
    if (transfer.type != TransactionType.transfer) {
      throw ArgumentError('Hanya transaksi transfer yang bisa diproses.');
    }
    if (fee < 0) {
      throw ArgumentError('Biaya admin tidak boleh negatif.');
    }

    final transferId = await _txRepo.save(transfer);

    // Biaya hanya dibuat saat tambah baru (bukan edit) agar tidak duplikat.
    if (fee > 0 && transfer.id == null) {
      final adminCat = (await _categoryRepo.defaults())
          .where((c) => c.name == 'Biaya Admin')
          .singleOrNull;
      if (adminCat == null || adminCat.id == null) {
        throw StateError('Kategori "Biaya Admin" tidak ditemukan.');
      }
      final now = DateTime.now();
      await _txRepo.save(Transaction(
        type: TransactionType.expense,
        amount: fee,
        categoryId: adminCat.id,
        accountId: transfer.accountId,
        merchant: transfer.merchant,
        date: transfer.date,
        note: 'Biaya admin transfer',
        createdAt: now,
      ));
    }

    return transferId;
  }
}

extension<T> on Iterable<T> {
  T? get singleOrNull => isEmpty ? null : single;
}
