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
  String get itemsLabel =>
      _id ? 'Item (opsional)' : 'Items (optional)';
  String get formIncomplete =>
      _id ? 'Lengkapi nominal dan akun dulu.' : 'Fill amount and account first.';
  String get savedSuccess => _id ? 'Berhasil disimpan!' : 'Saved successfully!';
  String get viewTransaction => _id ? 'Lihat transaksi' : 'View transaction';
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
  String minutesAgo(int m) => _id ? '$m mnt lalu' : '$m min ago';
  String hoursAgo(int h) => _id ? '$h jam lalu' : '$h hr ago';
  String daysAgo(int d) => _id ? '$d hari lalu' : '$d days ago';
  String get unknownMerchant => _id ? 'Transaksi' : 'Transaction';
  String get markDuplicate => _id ? 'Duplikat' : 'Duplicate';
  String get correctionNotFound =>
      _id ? 'Transaksi yang dimaksud tidak ditemukan.' : 'Transaction not found.';
  String get confirmDeleteTitle => _id ? 'Hapus transaksi?' : 'Delete transaction?';
  String confirmDeleteBody(String merchant, int amount) => _id
      ? 'Hapus "$merchant" sebesar $amount? Tindakan ini tidak bisa dibatalkan.'
      : 'Delete "$merchant" of $amount? This cannot be undone.';
  String get deleteAction => _id ? 'Hapus' : 'Delete';
  String get deleted => _id ? 'Transaksi dihapus.' : 'Transaction deleted.';
  String get corrected => _id ? 'Transaksi dikoreksi.' : 'Transaction corrected.';
  String get theme => _id ? 'Tema' : 'Theme';
  String get themeLight => _id ? 'Terang' : 'Light';
  String get themeDark => _id ? 'Gelap' : 'Dark';
  String get themeSystem => _id ? 'Ikuti sistem' : 'System';
  String get notifSetupTitle =>
      _id ? 'Auto-Catat Notifikasi' : 'Notification Auto-Record';
  String get notifHowItWorks => _id ? 'Cara kerja' : 'How it works';
  String get notifExplanation => _id
      ? 'DuitQu membaca notifikasi dari aplikasi yang kamu pilih, lalu mencatat transaksi secara otomatis. Hanya aplikasi terpilih yang dibaca. Kamu bisa mencabut izin kapan saja via Pengaturan Android.'
      : 'DuitQu reads notifications from apps you select, then records transactions automatically. Only selected apps are read. You can revoke access anytime via Android Settings.';
  String get notifStepPermission => _id ? 'Beri izin akses notifikasi' : 'Grant notification access';
  String get notifStepPermissionDesc => _id
      ? 'Android akan membuka Pengaturan — aktifkan akses untuk DuitQu.'
      : 'Android will open Settings — enable access for DuitQu.';
  String get notifStepApps => _id ? 'Pilih aplikasi sumber' : 'Choose source apps';
  String get notifStepAppsDesc => _id
      ? 'Hanya notifikasi dari aplikasi ini yang diproses.'
      : 'Only notifications from these apps are processed.';
  String get openSettings => _id ? 'Buka Pengaturan' : 'Open Settings';
  String get notifPrivacyNote => _id
      ? 'Catatan: tidak semua notifikasi bisa diproses (mis. notifikasi yang tidak mencantumkan nominal). Data notifikasi hanya disimpan lokal di HP.'
      : 'Note: not all notifications can be processed (e.g. ones without an amount). Notification data stays on your phone.';

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
  String get autoRecordSettings =>
      _id ? 'Pengaturan Auto-Catat' : 'Auto-Record Settings';
  String get autoRecordEnabled => _id ? 'Aktifkan auto-catat' : 'Enable auto-record';
  String get autoRecordEnabledDesc => _id
      ? 'Bila mati, semua hasil tangkapan masuk inbox untuk dicek manual.'
      : 'When off, all captured items go to the inbox for manual review.';
  String get autoRecordSources =>
      _id ? 'Sumber yang boleh auto-catat' : 'Sources allowed to auto-record';
  String confidenceThreshold(int pct) => _id
      ? 'Batas kepercayaan: $pct%'
      : 'Confidence threshold: $pct%';
  String get confidenceThresholdDesc => _id
      ? 'Hasil parsing di bawah batas ini masuk inbox, bukan langsung tersimpan.'
      : 'Parse results below this go to the inbox instead of saving directly.';
  String get policyHowItWorks => _id ? 'Cara kerja' : 'How it works';
  String get policyExplanation => _id
      ? 'Kandidat langsung tersimpan hanya bila: sumber diizinkan, tipe dikenali, nominal valid, akun pasti, bukan duplikat, dan kepercayaan parsing cukup. Selain itu masuk Inbox untuk kamu cek dulu.'
      : 'A candidate saves directly only when: the source is allowed, the type is recognized, the amount is valid, the account is certain, it is not a duplicate, and parse confidence is high enough. Otherwise it goes to the Inbox for you to review.';
  String get sourceManual => _id ? 'Input manual' : 'Manual input';
  String get sourceChat => _id ? 'Chat' : 'Chat';
  String get sourceNotification =>
      _id ? 'Notifikasi Android' : 'Android notifications';
  String get sourceReceipt => _id ? 'Pindai struk' : 'Receipt scan';
  String get sourceStatement => _id ? 'Impor mutasi' : 'Statement import';
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

  // -- mockup v2 redesign --
  String get seeDetails => _id ? 'Lihat detail' : 'See details';
  String get incomeFull => _id ? 'Pemasukan' : 'Income';
  String get expenseFull => _id ? 'Pengeluaran' : 'Expenses';
  String get noTransactionsTitle =>
      _id ? 'Belum ada transaksi' : 'No transactions yet';
  String get noTransactionsSubtitle => _id
      ? 'Yuk, mulai catat transaksi pertamamu!'
      : 'Come on, record your first transaction!';
  String get recordNow => _id ? 'Catat Sekarang' : 'Record Now';

  // -- insight: kartu tips maskot --
  String insightExpenseUp(String category, int pct) => _id
      ? 'Pengeluaran $category naik $pct% dibanding bulan lalu. Yuk, lebih hemat minggu ini! \u{1F4AA}'
      : 'Spending on $category is up $pct% vs last month. Save more this week! \u{1F4AA}';
  String insightIncomeUp(String category, int pct) => _id
      ? 'Pemasukan dari $category naik $pct% dibanding bulan lalu. Pertahankan! \u{1F389}'
      : 'Income from $category is up $pct% vs last month. Keep it up! \u{1F389}';
  String insightNewCategory(String category, String amount) => _id
      ? 'Ada catatan baru di $category ($amount) bulan ini. Pantau terus ya! \u{1F440}'
      : 'New activity in $category ($amount) this month. Keep an eye on it! \u{1F440}';
  String get insightCalm => _id
      ? 'Kabar baik! Catatan bulan ini terkendali. Pertahankan ritmenya! \u{1F44D}'
      : 'Good news! This month is under control. Keep the rhythm! \u{1F44D}';
  String get insightNoData => _id
      ? 'Belum cukup data untuk insight bulan ini. Tetap catat setiap transaksi ya! \u{1F4DD}'
      : 'Not enough data for insights this month. Keep recording every transaction! \u{1F4DD}';

  // -- chat assistant --
  String get chatAssistantTitle => _id ? 'DuitQu Assistant' : 'DuitQu Assistant';
  String get online => _id ? 'Online' : 'Online';
  String get chatInputHint => _id ? 'Tanya atau catat...' : 'Ask or record...';
  String get scanReceipt => _id ? 'Scan struk' : 'Scan receipt';
  String get receiptScanning =>
      _id ? 'Memindai struk... \u{1F4F7}' : 'Scanning receipt... \u{1F4F7}';
  String get receiptModelNotReady => _id
      ? 'Model OCR belum ter-download (\u224830 MB, butuh internet sekali). Hubungkan internet lalu coba scan lagi.'
      : 'OCR model not downloaded yet (\u224830 MB, needs internet once). Connect and try scanning again.';
  String get receiptReadOk => _id
      ? 'Aku sudah membaca struknya. Berikut hasilnya:'
      : 'I have read the receipt. Here is the result:';
  String receiptToInbox(String amount) => _id
      ? 'Struk terbaca: $amount. Cek Inbox untuk konfirmasi sebelum disimpan \u{1F4E5}'
      : 'Receipt read: $amount. Check Inbox to confirm before saving \u{1F4E5}';
  String get receiptDuplicate => _id
      ? 'Struk ini sudah pernah dipindai sebelumnya.'
      : 'This receipt was already scanned before.';
  String get receiptFailed =>
      _id ? 'Gagal memindai struk. Coba foto lebih jelas.' : 'Failed to scan receipt. Try a clearer photo.';
  String get attachScan => _id ? 'Scan struk' : 'Scan receipt';
  String get attachUploadPhoto => _id ? 'Upload foto' : 'Upload photo';
  String get attachPickFile => _id ? 'Pilih file' : 'Pick file';
  String get attachComingSoon => _id
      ? 'Segera hadir di update berikutnya.'
      : 'Coming soon in the next update.';
  String get chatGreeting => _id
      ? 'Halo! Ada transaksi baru yang mau dicatat? \u{1F60A}'
      : 'Hi! Any new transactions to record? \u{1F60A}';
  String get chatParsedOk =>
      _id ? 'Siap! Ini hasilnya \u{1F447}' : 'Got it! Here it is \u{1F447}';
  String get chatSaved =>
      _id ? 'Sudah tersimpan!' : 'Saved!';
  String get chatSavedAsk => _id
      ? 'Mau catat yang lain? \u{1F60A}'
      : 'Want to record another? \u{1F60A}';
  String get edit => _id ? 'Edit' : 'Edit';
  String get saveTransaction =>
      _id ? 'Simpan Transaksi' : 'Save Transaction';
  String get dateLabel => _id ? 'Tanggal' : 'Date';
  String get todayAt => _id ? 'Hari ini,' : 'Today,';
  String get listeningTitle => _id ? 'Mendengarkan...' : 'Listening...';
  String get listeningHint => _id
      ? 'Yoba ucapkan, misalnya:\n"Tadi beli kopi 25 ribu"'
      : 'Try saying, for example:\n"Bought coffee for 25 thousand earlier"';
  String get chatParseFail => _id
      ? 'Hmm, aku belum paham. Coba tulis nominalnya, misalnya "Makan siang 35 ribu".'
      : 'Hmm, I didn\'t quite get that. Try including the amount, e.g. "Lunch 35 thousand".';
  String get chatNoteDefault => _id ? 'Catatan' : 'Note';
  String get chatExamplesTitle =>
      _id ? 'Contoh yang bisa kamu tulis' : 'Things you can type';
  String get chatExample1 => _id
      ? 'Makan siang 35 ribu pakai GoPay'
      : 'Lunch 35 thousand with GoPay';
  String get chatExample2 =>
      _id ? 'Dapat gaji 5 juta' : 'Got salary 5 million';
  String get chatExample3 => _id
      ? 'Berapa pengeluaranku minggu ini?'
      : 'How much did I spend this week?';

  // -- chat bottom sheet --
  String get chatSheetTitle =>
      _id ? 'Catat transaksi dengan chat' : 'Record transactions with chat';
  String get chatSheetSubtitle => _id
      ? 'Tulis pengeluaran atau pemasukan dengan bahasa biasa, nanti aku yang catat. \u{2728}'
      : 'Type income or expenses in plain language, I\u2019ll record it for you. \u{2728}';
  String get chatSheetHint => _id
      ? 'Tulis transaksi, misalnya \u2018Beli kopi 28 ribu\u2019'
      : 'Type a transaction, e.g. \u2018Beli kopi 28 ribu\u2019';
  String get chatChipMore => _id ? 'Lainnya...' : 'More...';

  // -- chat AI full page --
  String get aiTitle => 'DuitQu AI';
  String get aiOnline => _id ? 'Siap membantu' : 'Ready to help';
  String aiGreeting(String? name) => name == null
      ? (_id ? 'Hai! \u{1F44B}' : 'Hi! \u{1F44B}')
      : (_id ? 'Hai, $name! \u{1F44B}' : 'Hi, $name! \u{1F44B}');
  String get aiSubtitle => _id
      ? 'Mau catat transaksi atau cek kondisi keuanganmu?'
      : 'Want to record a transaction or check your finances?';
  String get aiChipRecordExpense =>
      _id ? 'Catat pengeluaran' : 'Record expense';
  String get aiChipRecordIncome => _id ? 'Catat pemasukan' : 'Record income';
  String get aiChipMonthlyReport =>
      _id ? 'Laporan bulan ini' : 'This month\u2019s report';
  String get aiChipTopExpense =>
      _id ? 'Pengeluaran terbesar' : 'Biggest expense';
  String get aiInputHint =>
      _id ? 'Tulis pesan atau transaksi...' : 'Type a message or transaction...';
  String get aiClearHistory =>
      _id ? 'Bersihkan riwayat' : 'Clear chat history';
  String get aiSave => _id ? 'Simpan' : 'Save';
  String get aiNoData =>
      _id ? 'Belum ada transaksi bulan ini.' : 'No transactions this month yet.';
  String aiMonthlyReport(String income, String expense, String net) => _id
      ? 'Laporan bulan ini \u{1F4CA}\n\u2022 Pemasukan: $income\n\u2022 Pengeluaran: $expense\n\u2022 Selisih: $net'
      : 'This month\u2019s report \u{1F4CA}\n\u2022 Income: $income\n\u2022 Expenses: $expense\n\u2022 Net: $net';
  String aiTopExpense(String category, String amount) => _id
      ? 'Pengeluaran terbesarmu bulan ini: $category ($amount). \u{1F3AF}'
      : 'Your biggest expense this month: $category ($amount). \u{1F3AF}';
  String get expandChat => _id ? 'Buka layar penuh' : 'Open full screen';
  String get more => _id ? 'Lainnya' : 'More';

  // -- home (mockup baru) --
  String get quickIncome => _id ? 'Pemasukan' : 'Income';
  String get quickExpense => _id ? 'Pengeluaran' : 'Expense';
  String get quickTransactions => _id ? 'Transaksi' : 'Transactions';
  String get quickReport => _id ? 'Laporan' : 'Reports';
  String get monthlyBudget => _id ? 'Budget Bulan Ini' : 'This Month\u2019s Budget';
  String budgetFrom(String amount) => _id ? 'dari $amount' : 'of $amount';
  String get ctaTitle =>
      _id ? 'Yuk, catat transaksi hari ini!' : 'Let\u2019s record today\u2019s transactions!';
  String get ctaSubtitle => _id
      ? 'Biar keuanganmu tetap terpantau \u{1F4C8}'
      : 'Keep your finances on track \u{1F4C8}';
  String get searchTransactions =>
      _id ? 'Cari transaksi' : 'Search transactions';
  String get userNameTitle => _id ? 'Nama panggilan' : 'Nickname';
  String get userNameHint =>
      _id ? 'Nama untuk sapaan, mis. Dinda' : 'Name for greetings, e.g. Dinda';
  String get setName => _id ? 'Atur nama' : 'Set name';

  // -- insight --
  String get expenseTab => _id ? 'Pengeluaran' : 'Expenses';
  String get incomeTab => _id ? 'Pemasukan' : 'Income';
  String budgetPercent(int percent) =>
      _id ? '$percent% dari budget' : '$percent% of budget';

  // -- tujuan --
  String collected(String amount) =>
      _id ? 'Terkumpul $amount' : 'Collected $amount';
  String get noGoalsTitle =>
      _id ? 'Yuk, capai tujuanmu!' : "Let's reach your goals!";
  String get noGoalsSubtitle => _id
      ? 'Mulai menabung untuk rencana besar kamu di masa depan.'
      : 'Start saving for your big plans ahead.';
  String get createGoal => _id ? 'Buat Tujuan' : 'Create Goal';
  String get deleteGoalTitle => _id ? 'Hapus tujuan?' : 'Delete goal?';
  String deleteGoalMessage(String name) => _id
      ? 'Tujuan "$name" beserta dana terkumpulnya akan dihapus.'
      : 'Goal "$name" and its saved funds will be deleted.';

  // -- profil --
  String get menuAccounts => _id ? 'Akun & Saldo' : 'Accounts & Balance';
  String get menuCategories => _id ? 'Kategori' : 'Categories';
  String get menuBudget => _id ? 'Budget' : 'Budget';
  String get menuGoals => _id ? 'Tujuan' : 'Goals';
  String get menuAutoRecord => _id ? 'Auto-Catat' : 'Auto-Record';
  String get menuBackupSync =>
      _id ? 'Backup & Sinkronisasi' : 'Backup & Sync';
  String get menuSecurity =>
      _id ? 'Keamanan & Privasi' : 'Security & Privacy';
  String get menuSettings => _id ? 'Pengaturan' : 'Settings';
  String get menuHelp => _id ? 'Bantuan & Saran' : 'Help & Feedback';
  String get menuAbout => _id ? 'Tentang DuitQu' : 'About DuitQu';
  String get cloudSync => _id ? 'Sinkronisasi Cloud' : 'Cloud Sync';

  // -- inbox --
  String get newest => _id ? 'Terbaru' : 'Newest';

  // -- success state --
  String get savedTitle => _id ? 'Berhasil Disimpan!' : 'Saved!';
  String get savedSubtitle =>
      _id ? 'Transaksi sudah dicatat \u{1F389}' : 'Transaction recorded \u{1F389}';
  String get recordAgain => _id ? 'Catat Lagi' : 'Record Again';
  String get viewTransactions =>
      _id ? 'Lihat Transaksi' : 'View Transactions';
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
