import 'package:flutter/material.dart';

import '../../data/backup_service.dart';

/// Lokalisasi hand-rolled ID/EN untuk DuitQu.
///
/// Dipakai via `AppLocalizations.of(context)`. Bahasa mengikuti bahasa
/// perangkat bila didukung (id/en), selain itu Bahasa Indonesia.
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const supportedLocales = [Locale('id'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get _id => locale.languageCode != 'en';

  // -- umum --
  String get appTitle => 'DuitQu';
  String get cancel => _id ? 'Batal' : 'Cancel';
  String get close => _id ? 'Tutup' : 'Close';
  String get reset => _id ? 'Reset' : 'Reset';
  String get apply => _id ? 'Terapkan' : 'Apply';
  String get delete => _id ? 'Hapus' : 'Delete';
  String get accountLabel => _id ? 'Akun' : 'Account';
  String get categoryLabel => _id ? 'Kategori' : 'Category';

  // -- tipe transaksi --
  String get income => _id ? 'Masuk' : 'Income';
  String get expense => _id ? 'Keluar' : 'Expense';
  String get transfer => _id ? 'Transfer' : 'Transfer';

  // -- home --
  String get backupTooltip => _id ? 'Backup' : 'Backup';
  String get searchHint => _id
      ? 'Cari catatan, merchant, barang…'
      : 'Search notes, merchants, items…';
  String get filterTitle => _id ? 'Filter riwayat' : 'Filter history';
  String get allAccounts => _id ? 'Semua akun' : 'All accounts';
  String get allCategories => _id ? 'Semua kategori' : 'All categories';
  String get deleteTransactionTitle =>
      _id ? 'Hapus transaksi?' : 'Delete transaction?';
  String get deleteTransactionMessage => _id
      ? 'Transaksi ini akan dihapus permanen.'
      : 'This transaction will be permanently deleted.';
  String get deleteTransaction =>
      _id ? 'Hapus transaksi' : 'Delete transaction';

  // -- tambah transaksi --
  String get save => _id ? 'Catat' : 'Save';
  String get saveChanges => _id ? 'Simpan perubahan' : 'Save changes';
  String get toAccountLabel => _id ? 'Ke akun' : 'To account';
  String get fromAccountLabel => _id ? 'Dari akun' : 'From account';
  String get amountLabel => _id ? 'Nominal (Rp)' : 'Amount (Rp)';
  String get amountAutoLabel =>
      _id ? 'Total otomatis dari item' : 'Auto total from items';
  String get adminFeeLabel =>
      _id ? 'Biaya admin (opsional)' : 'Admin fee (optional)';
  String get adminFeeHint => _id
      ? 'Otomatis tercatat sebagai pengeluaran "Biaya Admin".'
      : 'Automatically recorded as a "Biaya Admin" expense.';
  String get noteLabel => _id ? 'Catatan (opsional)' : 'Note (optional)';
  String get merchantLabel =>
      _id ? 'Merchant (opsional)' : 'Merchant (optional)';
  String get itemsSection =>
      _id ? 'Rincian item (opsional)' : 'Item details (optional)';
  String get addItem => _id ? 'Tambah item' : 'Add item';
  String get itemName => _id ? 'Nama barang' : 'Item name';
  String get price => _id ? 'Harga' : 'Price';
  String get qty => 'Qty';
  String get net => _id ? 'Selisih' : 'Net';
  String get emptyHistory => _id
      ? 'Belum ada transaksi.\nKetuk + untuk mencatat.'
      : 'No transactions yet.\nTap + to record one.';

  // -- backup --
  String get backupFailed => _id ? 'Backup gagal' : 'Backup failed';
  String get importDone => _id ? 'Impor selesai' : 'Import finished';
  String get exportCsv => _id ? 'Ekspor CSV' : 'Export CSV';
  String get exportCsvSubtitle =>
      _id ? 'Simpan seluruh data ke satu file' : 'Save all data to one file';
  String get importCsv => _id ? 'Impor CSV' : 'Import CSV';
  String get importCsvSubtitle =>
      _id ? 'Pulihkan dari file backup' : 'Restore from a backup file';

  String importSummary(
    int accounts,
    int categories,
    int transactions,
    int items,
  ) => _id
      ? 'Berhasil diimpor: $accounts akun, $categories kategori, '
            '$transactions transaksi, $items item.'
      : 'Imported: $accounts accounts, $categories categories, '
            '$transactions transactions, $items items.';

  String skippedRowsTitle(int count) =>
      _id ? '$count baris dilewati:' : '$count rows skipped:';

  String skippedRowLine(int row, String reason) =>
      _id ? 'Baris $row: $reason' : 'Row $row: $reason';

  String exportFailed(Object e) =>
      _id ? 'Gagal mengekspor: $e' : 'Export failed: $e';
  String importFailed(Object e) =>
      _id ? 'Gagal mengimpor: $e' : 'Import failed: $e';

  // -- navigasi & layar baru --
  String get navHome => _id ? 'Beranda' : 'Home';
  String get navStats => _id ? 'Statistik' : 'Stats';
  String get navAccounts => _id ? 'Akun' : 'Accounts';
  String get navMore => _id ? 'Lainnya' : 'More';
  String get navInsight => _id ? 'Insight' : 'Insight';
  String get navGoals => _id ? 'Tujuan' : 'Goals';
  String get navInbox => _id ? 'Inbox' : 'Inbox';
  String get totalBalance => _id ? 'Total Saldo' : 'Total Balance';
  String get recentTransactions =>
      _id ? 'Transaksi Terbaru' : 'Recent transactions';
  String get seeAll => _id ? 'Lihat semua' : 'See all';
  String get seeDetail => _id ? 'Lihat detail' : 'See details';

  // -- mockup: sapaan & chat --
  String get goodMorning => _id ? 'Selamat pagi,' : 'Good morning,';
  String get goodAfternoon => _id ? 'Selamat siang,' : 'Good afternoon,';
  String get goodEvening => _id ? 'Selamat sore,' : 'Good evening,';
  String get goodNight => _id ? 'Selamat malam,' : 'Good evening,';
  String get greetingQuestion =>
      _id ? 'Ada rencana seru hari ini? ✨' : 'Any fun plans today? ✨';
  String get chatHint => _id ? 'Tanya atau catat...' : 'Ask or record...';
  String get chatHintLong => _id
      ? 'Ketik mis. "Makan siang 35 ribu pakai GoPay"...'
      : 'Type e.g. "Lunch 35 thousand with GoPay"...';
  String get listening => _id ? 'Mendengarkan...' : 'Listening...';

  // -- mockup: budget --
  String get remainingThisMonth =>
      _id ? 'Sisa Bulan Ini' : 'Remaining This Month';
  String get setBudgetTitle =>
      _id ? 'Atur budget bulanan' : 'Set monthly budget';
  String get budgetLabel => _id ? 'Budget (Rp)' : 'Budget (Rp)';
  String get setBudgetPrompt =>
      _id ? 'Yuk atur budget bulananmu' : 'Set your monthly budget';
  String budgetUsed(int pct) => _id
      ? 'Kamu sudah pakai $pct% dari budget bulanan'
      : 'You have used $pct% of your monthly budget';

  // -- mockup: insight --
  String get insightTitle => _id ? 'Insight' : 'Insight';
  String get expenseThisMonth => _id ? 'Pengeluaran' : 'Expenses';
  String get ofBudget => _id ? 'dari budget' : 'of budget';

  // -- mockup: tujuan --
  String get goalsTitle => _id ? 'Tujuan' : 'Goals';
  String get addGoal => _id ? 'Tambah tujuan' : 'Add goal';
  String get goalName => _id ? 'Nama tujuan' : 'Goal name';
  String get targetAmount => _id ? 'Target (Rp)' : 'Target (Rp)';
  String get savedAmount => _id ? 'Terkumpul' : 'Saved';
  String get addFunds => _id ? 'Tambah dana' : 'Add funds';
  String get noGoals => _id
      ? 'Belum ada tujuan. Yuk buat target nabung pertamamu!'
      : 'No goals yet. Create your first saving target!';

  // -- mockup: inbox --
  String get inboxTitle => _id ? 'Inbox Auto-Catat' : 'Auto-Record Inbox';
  String get needsConfirmation => _id ? 'Perlu Konfirmasi' : 'Needs Review';
  String get latest => _id ? 'Terbaru' : 'Latest';
  String get ignore => _id ? 'Abaikan' : 'Ignore';
  String get saveAction => _id ? 'Simpan' : 'Save';
  String get inboxEmpty => _id
      ? 'Belum ada yang perlu dikonfirmasi.\nTransaksi dari notifikasi akan muncul di sini.'
      : 'Nothing to review yet.\nTransactions from notifications will appear here.';
  String get justNow => _id ? 'Baru saja' : 'Just now';

  // -- mockup: profil --
  String get profileTitle => _id ? 'Profil & Lainnya' : 'Profile & More';
  String get manageAccount =>
      _id ? 'Kelola akun & preferensi' : 'Manage account & preferences';
  String get accountsAndBalance => _id ? 'Akun & Saldo' : 'Accounts & Balance';
  String get budget => _id ? 'Budget' : 'Budget';
  String get autoRecord => _id ? 'Auto-Catat' : 'Auto-Record';
  String get backupAndSync => _id ? 'Backup & Sinkronisasi' : 'Backup & Sync';
  String get securityAndPrivacy =>
      _id ? 'Keamanan & Privasi' : 'Security & Privacy';
  String get settings => _id ? 'Pengaturan' : 'Settings';
  String get helpAndFeedback => _id ? 'Bantuan & Saran' : 'Help & Feedback';
  String get active => _id ? 'Aktif' : 'Active';
  String get comingSoon => _id ? 'Segera hadir di v4' : 'Coming in v4';
  String get noTransactionsThisMonth =>
      _id ? 'Belum ada transaksi bulan ini.' : 'No transactions this month.';
  String get thisMonth => _id ? 'Bulan ini' : 'This month';
  String get topCategories => _id ? 'Kategori teratas' : 'Top categories';
  String get addAccount => _id ? 'Tambah akun' : 'Add account';
  String get editAccount => _id ? 'Ubah akun' : 'Edit account';
  String get accountName => _id ? 'Nama akun' : 'Account name';
  String get initialBalance => _id ? 'Saldo awal (Rp)' : 'Initial balance (Rp)';
  String get deleteAccountTitle => _id ? 'Hapus akun?' : 'Delete account?';
  String deleteAccountMessage(String name) => _id
      ? 'Akun "$name" beserta seluruh transaksinya akan dihapus.'
      : 'Account "$name" and all its transactions will be deleted.';
  String get categoriesTitle => _id ? 'Kategori' : 'Categories';
  String get backupTitle => _id ? 'Backup' : 'Backup';
  String get aboutTitle => _id ? 'Tentang' : 'About';
  String get aboutText => _id
      ? 'DuitQu — pencatat keuangan pribadi. 100% offline, datamu hanya milikmu.'
      : 'DuitQu — personal money tracker. 100% offline, your data stays yours.';
  String get versionLabel => _id ? 'Versi' : 'Version';
  String get today => _id ? 'Hari ini' : 'Today';
  String get yesterday => _id ? 'Kemarin' : 'Yesterday';
  String get addTransactionTitle =>
      _id ? 'Catat transaksi' : 'Record transaction';
  String get editTransactionTitle =>
      _id ? 'Ubah transaksi' : 'Edit transaction';

  // -- bulan --
  static const _shortId = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  static const _shortEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _longId = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  static const _longEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String shortMonth(int month) => (_id ? _shortId : _shortEn)[month - 1];
  String longMonth(int month) => (_id ? _longId : _longEn)[month - 1];

  // -- alasan baris dilewati (kode dari BackupService) --
  String skippedReason(String code, List<String> args) {
    switch (code) {
      case 'tooManyColumns':
        return _id
            ? 'kelebihan kolom (${args[0]} > ${args[1]})'
            : 'too many columns (${args[0]} > ${args[1]})';
      case 'unknownRecord':
        return _id
            ? 'tipe record tidak dikenal: "${args[0]}"'
            : 'unknown record type: "${args[0]}"';
      case 'notANumber':
        return _id
            ? 'kolom ${args[0]} bukan angka: "${args[1]}"'
            : 'column ${args[0]} is not a number: "${args[1]}"';
      case 'unknownAccountType':
        return _id
            ? 'tipe akun tidak dikenal: "${args[0]}"'
            : 'unknown account type: "${args[0]}"';
      case 'emptyAccountName':
        return _id ? 'nama akun kosong' : 'empty account name';
      case 'emptyCategoryName':
        return _id ? 'nama kategori kosong' : 'empty category name';
      case 'unknownTxType':
        return _id
            ? 'tipe transaksi tidak dikenal: "${args[0]}"'
            : 'unknown transaction type: "${args[0]}"';
      case 'amountNotPositive':
        return _id ? 'amount harus > 0' : 'amount must be > 0';
      case 'transferNoDestination':
        return _id
            ? 'transfer tanpa akun tujuan'
            : 'transfer without destination account';
      case 'emptyItemName':
        return _id ? 'nama item kosong' : 'empty item name';
      case 'negativePrice':
        return _id ? 'price negatif' : 'negative price';
      case 'qtyNotPositive':
        return _id ? 'qty harus > 0' : 'qty must be > 0';
      case 'accountMissing':
        return _id
            ? 'akun ${args[0]} tidak ada di file backup'
            : 'account ${args[0]} not in backup file';
      case 'toAccountMissing':
        return _id
            ? 'akun tujuan ${args[0]} tidak ada di file backup'
            : 'destination account ${args[0]} not in backup file';
      case 'categoryMissing':
        return _id
            ? 'kategori ${args[0]} tidak ada di file backup'
            : 'category ${args[0]} not in backup file';
      case 'transactionMissing':
        return _id
            ? 'transaksi ${args[0]} tidak ada di file backup'
            : 'transaction ${args[0]} not in backup file';
      default:
        return args.isEmpty ? code : '$code: ${args.join(', ')}';
    }
  }

  /// Pesan untuk [BackupFormatException] berdasarkan kodenya.
  String backupFormatMessage(String code) {
    switch (code) {
      case 'notCsv':
        return _id ? 'File bukan CSV yang valid.' : 'File is not valid CSV.';
      case 'emptyFile':
        return _id
            ? 'File kosong atau terpotong.'
            : 'File is empty or truncated.';
      case 'badTag':
        return _id
            ? 'Bukan file backup DuitQu (tag tidak cocok).'
            : 'Not a DuitQu backup file (tag mismatch).';
      case 'badHeader':
        return _id
            ? 'Header tidak dikenali — mungkin versi backup berbeda.'
            : 'Unrecognized header — backup may be from another version.';
      default:
        return code;
    }
  }

  /// Alasan impor yang sudah dilokalkan untuk satu baris yang dilewati.
  String localizedSkippedReason(SkippedRow s) => skippedReason(s.code, s.args);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['id', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
