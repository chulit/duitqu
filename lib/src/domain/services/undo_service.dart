import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Satu aksi yang bisa di-undo.
class UndoableAction {
  final String label;
  final int transactionId;
  final DateTime createdAt;

  const UndoableAction({
    required this.label,
    required this.transactionId,
    required this.createdAt,
  });
}

/// Undo untuk transaksi hasil pencatatan otomatis (tiket 07, spec v2).
///
/// Menyimpan tumpukan aksi terakhir dalam memori. Undo menghapus
/// transaksi yang baru disimpan (bukan soft-delete — sesuai aturan
/// penghapusan data eksplisit).
class UndoService {
  final TransactionRepository _txRepo;
  final List<UndoableAction> _stack = [];

  /// Maksimal aksi yang disimpan.
  static const int maxStack = 20;

  UndoService(this._txRepo);

  /// Catat transaksi yang baru disimpan otomatis.
  void recordAutoSave(Transaction tx) {
    final id = tx.id;
    if (id == null) return;
    _stack.add(UndoableAction(
      label: tx.merchant ?? 'Transaksi',
      transactionId: id,
      createdAt: DateTime.now(),
    ));
    if (_stack.length > maxStack) {
      _stack.removeAt(0);
    }
  }

  /// Aksi terakhir yang bisa di-undo, null bila kosong.
  UndoableAction? get lastUndoable =>
      _stack.isEmpty ? null : _stack.last;

  /// Batalkan aksi terakhir: hapus transaksinya.
  /// Mengembalikan label aksi yang dibatalkan.
  Future<String?> undoLast() async {
    if (_stack.isEmpty) return null;
    final action = _stack.removeLast();
    await _txRepo.delete(action.transactionId);
    return action.label;
  }

  /// Bersihkan tumpukan (mis. saat logout/ganti DB).
  void clear() => _stack.clear();
}
