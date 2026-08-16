// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get home => 'Beranda';

  @override
  String get analytics => 'Analisis';

  @override
  String get transactions => 'Transaksi';

  @override
  String get settings => 'Pengaturan';

  @override
  String get more => 'Lainnya';

  @override
  String get preferences => 'Preferensi';

  @override
  String get currency => 'Mata Uang';

  @override
  String get theme => 'Tema';

  @override
  String get language => 'Bahasa';

  @override
  String get payday => 'Hari Gajian';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameIndonesian => 'Bahasa Indonesia';

  @override
  String appVersionLabel(String version) {
    return 'Versi $version';
  }

  @override
  String get appTagline => 'Dibuat untuk Anda';

  @override
  String get csvExportShareSubject => 'Ekspor Finta';

  @override
  String get manage => 'Kelola';

  @override
  String get categories => 'Kategori';

  @override
  String get budgets => 'Anggaran';

  @override
  String get recurring => 'Rutin';

  @override
  String get data => 'Data';

  @override
  String get exportCsv => 'Ekspor ke CSV';

  @override
  String get save => 'Simpan';

  @override
  String get cancel => 'Batal';

  @override
  String get add => 'Tambah';

  @override
  String get delete => 'Hapus';

  @override
  String get edit => 'Ubah';

  @override
  String get system => 'Sistem';

  @override
  String get light => 'Terang';

  @override
  String get dark => 'Gelap';

  @override
  String get totalBalance => 'Total Saldo';

  @override
  String get netThisPeriod => 'Bersih Periode Ini';

  @override
  String get income => 'Pemasukan';

  @override
  String get expense => 'Pengeluaran';

  @override
  String get recentTransactions => 'Transaksi Terakhir';

  @override
  String get seeAll => 'Lihat Semua';

  @override
  String get noRecentTransactions => 'Tidak ada transaksi';

  @override
  String get expenseBreakdown => 'Rincian Pengeluaran';

  @override
  String get noDataForThisPeriod => 'Tidak ada data untuk periode ini';

  @override
  String get totalSpent => 'Total Pengeluaran';

  @override
  String get chartTotal => 'Total';

  @override
  String get heatmapTapHint => 'Ketuk tanggal untuk melihat transaksinya';

  @override
  String get totalIncome => 'Total Pemasukan';

  @override
  String get totalExpense => 'Total Pengeluaran';

  @override
  String get addTransaction => 'Tambah Transaksi';

  @override
  String get editTransaction => 'Ubah Transaksi';

  @override
  String get noteOptional => 'Catatan (opsional)';

  @override
  String get amount => 'Jumlah';

  @override
  String get date => 'Tanggal';

  @override
  String get saveTransaction => 'Simpan Transaksi';

  @override
  String get saveChanges => 'Simpan Perubahan';

  @override
  String get pleaseEnterValidAmount => 'Masukkan jumlah yang valid';

  @override
  String get pleaseSelectCategory => 'Pilih kategori';

  @override
  String get moreOptions => 'Opsi lainnya';

  @override
  String get manageCategories => 'Kelola Kategori';

  @override
  String get addCategory => 'Tambah Kategori';

  @override
  String get editCategory => 'Ubah Kategori';

  @override
  String get categoryName => 'Nama Kategori';

  @override
  String get icon => 'Ikon';

  @override
  String get color => 'Warna';

  @override
  String get manageBudgets => 'Kelola Anggaran';

  @override
  String get addBudget => 'Tambah Anggaran';

  @override
  String get editBudget => 'Edit Anggaran';

  @override
  String get budgetAmount => 'Jumlah Anggaran';

  @override
  String get spent => 'Terpakai';

  @override
  String get remaining => 'Tersisa';

  @override
  String get recurringTransactions => 'Transaksi Rutin';

  @override
  String get addRecurring => 'Tambah Rutin';

  @override
  String get frequency => 'Frekuensi';

  @override
  String get daily => 'Harian';

  @override
  String get weekly => 'Mingguan';

  @override
  String get monthly => 'Bulanan';

  @override
  String get yearly => 'Tahunan';

  @override
  String get nextDate => 'Tanggal Berikutnya';

  @override
  String get active => 'Aktif';

  @override
  String get paused => 'Dijeda';

  @override
  String get welcomeToFinta => 'Selamat Datang di Finta';

  @override
  String get trackYourExpensesEasily => 'Lacak pengeluaran Anda dengan mudah.';

  @override
  String get getStarted => 'Mulai';

  @override
  String get confirmDelete => 'Apakah Anda yakin ingin menghapus ini?';

  @override
  String get archive => 'Arsipkan';

  @override
  String archivedCount(int count) {
    return 'Diarsipkan ($count)';
  }

  @override
  String get deletePermanently => 'Hapus permanen';

  @override
  String get archiveCategory => 'Arsipkan Kategori';

  @override
  String confirmDeleteCategory(String name) {
    return 'Hapus \"$name\"? Kategori ini belum memiliki transaksi, jadi aman untuk dihapus.';
  }

  @override
  String confirmArchiveCategory(String name, int count) {
    return '\"$name\" digunakan oleh $count transaksi. Kategori ini akan disembunyikan dari entri baru, tetapi transaksi tersebut akan tetap menyimpan label kategorinya — tidak ada yang dihapus.';
  }

  @override
  String get yes => 'Ya';

  @override
  String get no => 'Tidak';

  @override
  String get history => 'Riwayat';

  @override
  String get yearlyReport => 'Laporan Tahunan';

  @override
  String get summary => 'Ringkasan';

  @override
  String get netSavings => 'Tabungan Bersih';

  @override
  String get searchNotes => 'Cari catatan...';

  @override
  String get all => 'Semua';

  @override
  String get noTransactionsFound => 'Tidak ada transaksi ditemukan';

  @override
  String get tryAdjustingSearch => 'Coba sesuaikan pencarian Anda';

  @override
  String get noTransactionsYet => 'Anda belum menambahkan transaksi apa pun';

  @override
  String get incomeAmount => 'Jumlah Pemasukan';

  @override
  String get expenseAmount => 'Jumlah Pengeluaran';

  @override
  String get category => 'Kategori';

  @override
  String get defaultCategory => 'Bawaan';

  @override
  String get selectACategory => 'Pilih kategori...';

  @override
  String get searchCategories => 'Cari kategori...';

  @override
  String get createNewCategory => 'Buat Kategori Baru';

  @override
  String get noCategoriesFound => 'Kategori tidak ditemukan';

  @override
  String get makeThisRecurring => 'Jadikan ini rutin?';

  @override
  String get biweekly => 'Setiap 2 minggu';

  @override
  String get pleaseEnterName => 'Harap masukkan nama';

  @override
  String get noBudgetsYet => 'Belum ada anggaran';

  @override
  String get setMonthlyLimits =>
      'Tetapkan batas bulanan untuk melacak pengeluaran Anda';

  @override
  String get ofString => 'dari';

  @override
  String get deleteBudget => 'Hapus Anggaran';

  @override
  String removeBudgetFor(String category) {
    return 'Hapus anggaran untuk $category?';
  }

  @override
  String get newBudget => 'Anggaran Baru';

  @override
  String get saveBudget => 'Simpan Anggaran';

  @override
  String get budgetAlreadyExistsForCategory =>
      'Anggaran untuk kategori ini sudah ada';

  @override
  String get used => 'terpakai';

  @override
  String get spentString => 'terpakai';

  @override
  String get left => 'tersisa';

  @override
  String get overString => 'melebihi';

  @override
  String get noRecurringTransactions => 'Belum ada transaksi rutin';

  @override
  String get enableRecurringWhenAdding =>
      'Aktifkan \"rutin\" saat menambah transaksi';

  @override
  String get unknown => 'Tidak diketahui';

  @override
  String get next => 'Berikutnya';

  @override
  String get stopRecurring => 'Hentikan Rutin';

  @override
  String get stopRecurringMessage =>
      'Ini akan menghentikan pembuatan transaksi otomatis di masa depan. Transaksi yang ada akan tetap dipertahankan.';

  @override
  String get recurringStopped => 'Transaksi berulang dihentikan';

  @override
  String get stop => 'Hentikan';

  @override
  String get skip => 'Lewati';

  @override
  String get trackYourMoney => 'Lacak uang Anda,\nbukan stres Anda';

  @override
  String get chooseYourCurrency => 'Pilih mata uang Anda';

  @override
  String get currencyDisplayOnly =>
      'Ini hanya untuk tampilan — tidak ada konversi';

  @override
  String get whenDoYouGetPaid => 'Kapan Anda gajian?';

  @override
  String get paydayDescription =>
      'Periode pelacakan Anda diatur ulang pada hari ini setiap bulan';

  @override
  String get startTracking => 'Mulai Melacak';

  @override
  String get budgetExceededAlert =>
      'Anda telah melebihi anggaran untuk kategori ini';

  @override
  String budgetWarningAlert(Object pct) {
    return 'Perhatian — Anda telah menggunakan $pct% dari anggaran Anda';
  }

  @override
  String get errorFailedToSave => 'Gagal menyimpan. Silakan coba lagi.';

  @override
  String get errorFailedToDelete => 'Gagal menghapus. Silakan coba lagi.';

  @override
  String get categoryAlreadyExists => 'Kategori dengan nama ini sudah ada';

  @override
  String get retry => 'Coba Lagi';

  @override
  String get overBudget => 'Melebihi Anggaran!';

  @override
  String get backupYourData => 'Cadangkan data Anda';

  @override
  String get upcoming => 'Akan Datang';

  @override
  String get dueToday => 'Hari ini';

  @override
  String get dueTomorrow => 'Besok';

  @override
  String dueInDays(int days) {
    return 'dalam $days hari';
  }

  @override
  String showAllCount(int count) {
    return 'Lihat semua ($count)';
  }

  @override
  String get createFirstBudget => 'Buat anggaran pertama Anda';

  @override
  String get addTransactionCta => 'Tambah transaksi';

  @override
  String get createCategory => 'Buat kategori';

  @override
  String get createFirstRecurring => 'Atur transaksi rutin';

  @override
  String get year => 'Tahun';

  @override
  String get noTransactionsOnThisDay => 'Tidak ada transaksi pada hari ini';

  @override
  String get period => 'Periode';

  @override
  String get paceAhead => 'Lebih cepat dari perkiraan';

  @override
  String get paceOnTrack => 'Sesuai jalur';

  @override
  String get paceUnder => 'Lebih lambat dari perkiraan';

  @override
  String get safeToSpendLabel => 'Aman dibelanjakan per hari';

  @override
  String get hideBalances => 'Sembunyikan saldo';

  @override
  String get showBalances => 'Tampilkan saldo';

  @override
  String get currentPayPeriod => 'Periode gaji saat ini';

  @override
  String get leftThisPeriod => 'Sisa periode ini';

  @override
  String spentOfTotal(String spent, String total) {
    return '$spent dari $total terpakai';
  }

  @override
  String percentVsLast(String percent) {
    return '$percent% vs sebelumnya';
  }

  @override
  String get filters => 'Filter';

  @override
  String get clearFilters => 'Hapus semua';

  @override
  String get dateRange => 'Rentang tanggal';

  @override
  String get anyTime => 'Kapan saja';

  @override
  String get thisPeriod => 'Periode ini';

  @override
  String get lastPeriod => 'Periode lalu';

  @override
  String get last3Months => '3 bulan terakhir';

  @override
  String get customRange => 'Kustom';

  @override
  String get type => 'Jenis';

  @override
  String get amountRange => 'Rentang jumlah';

  @override
  String get minAmount => 'Min';

  @override
  String get maxAmount => 'Maks';

  @override
  String get applyFilters => 'Terapkan filter';

  @override
  String transactionsSummary(int count, String total) {
    return '$count transaksi · $total';
  }

  @override
  String get whereItWent => 'Ke mana perginya';

  @override
  String get reports => 'Laporan';

  @override
  String get paceInfoTitle => 'Kecepatan belanja';

  @override
  String get paceExplanation =>
      'Membandingkan seberapa banyak anggaran yang sudah kamu pakai dengan seberapa jauh periode ini sudah berjalan. Garis tegak di batang menandai hari ini — jika warna terisi sudah melewati garis itu, kamu membelanjakan lebih cepat dari waktu yang berjalan (lebih cepat dari perkiraan); jika belum mencapai garis, kamu membelanjakan lebih lambat (lebih lambat dari perkiraan).';

  @override
  String get gotIt => 'Mengerti';

  @override
  String get accounts => 'Akun';

  @override
  String get account => 'Akun';

  @override
  String get manageAccounts => 'Kelola Akun';

  @override
  String get addAccount => 'Tambah Akun';

  @override
  String get editAccount => 'Ubah Akun';

  @override
  String get accountName => 'Nama Akun';

  @override
  String get accountType => 'Jenis Akun';

  @override
  String get openingBalance => 'Saldo Awal';

  @override
  String get creditLimitOptional => 'Limit Kartu Kredit (opsional)';

  @override
  String get includeInTotal => 'Sertakan dalam total';

  @override
  String get includeInTotalDescription =>
      'Dihitung dalam kekayaan bersih dan kas tersedia';

  @override
  String get netWorth => 'Kekayaan Bersih';

  @override
  String get selectAnAccount => 'Pilih akun';

  @override
  String get noAccountsYet => 'Belum ada akun';

  @override
  String get noAccountsYetMessage =>
      'Tambahkan akun untuk mulai melacak saldo di dompet, bank, dan kartu kamu';

  @override
  String get archiveAccount => 'Arsipkan Akun';

  @override
  String confirmArchiveAccountUnused(String name) {
    return 'Arsipkan \"$name\"? Akun ini akan disembunyikan dari entri baru.';
  }

  @override
  String confirmArchiveAccount(String name, int count) {
    return '\"$name\" digunakan oleh $count transaksi. Akun ini akan disembunyikan dari entri baru, tetapi transaksi tersebut akan tetap menyimpan label akunnya — tidak ada yang dihapus.';
  }

  @override
  String amountOwed(String amount) {
    return 'Utang $amount';
  }

  @override
  String get accountTypeCash => 'Tunai';

  @override
  String get accountTypeBank => 'Bank';

  @override
  String get accountTypeCreditCard => 'Kartu Kredit';

  @override
  String get accountTypeEWallet => 'E-Wallet';

  @override
  String get accountTypeSavings => 'Tabungan';

  @override
  String get accountTypeInvestment => 'Investasi';

  @override
  String get transfer => 'Transfer';

  @override
  String get transferAmount => 'Jumlah Transfer';

  @override
  String get fromAccount => 'Dari';

  @override
  String get toAccount => 'Ke';

  @override
  String get deleteTransfer => 'Hapus Transfer';

  @override
  String get confirmDeleteTransfer =>
      'Hapus transfer ini? Kedua sisi transfer akan dihapus.';

  @override
  String transferOutOf(String account) {
    return 'Keluar dari $account';
  }

  @override
  String transferIntoAccount(String account) {
    return 'Masuk ke $account';
  }

  @override
  String get merchant => 'Merchant';

  @override
  String get merchantHint => 'Belanja di mana?';

  @override
  String get parentCategoryOptional => 'Kategori induk (opsional)';

  @override
  String get noneTopLevel => 'Tidak ada — kategori tingkat atas';

  @override
  String get groupSubcategories => 'Gabungkan sub-kategori';

  @override
  String get showSubcategories => 'Tampilkan sub-kategori';

  @override
  String percentMoreThanLastPeriod(String percent) {
    return '$percent% lebih tinggi dari periode lalu';
  }

  @override
  String percentLessThanLastPeriod(String percent) {
    return '$percent% lebih rendah dari periode lalu';
  }

  @override
  String get overallBudget => 'Anggaran Keseluruhan';

  @override
  String get groupBudget => 'Anggaran Grup';

  @override
  String get budgetScope => 'Anggaran mencakup';

  @override
  String get budgetScopeCategory => 'Satu kategori';

  @override
  String get budgetScopeGroup => 'Grup kategori';

  @override
  String get budgetScopeOverall => 'Semuanya';

  @override
  String get budgetName => 'Nama anggaran';

  @override
  String get budgetNameOptional => 'Nama anggaran (opsional)';

  @override
  String get budgetPeriod => 'Periode';

  @override
  String get budgetRepeat => 'Ulangi setiap periode';

  @override
  String budgetRepeatRenewsOn(String date) {
    return 'Diperbarui $date.';
  }

  @override
  String budgetRepeatEndsOn(String date) {
    return 'Berakhir $date. Hanya mencakup periode ini.';
  }

  @override
  String get endedBudgets => 'Berakhir';

  @override
  String budgetEndedOn(String date) {
    return 'Berakhir $date';
  }

  @override
  String get budgetRollover => 'Rollover';

  @override
  String get budgetRolloverExplanation =>
      'Bawa sisa (atau kelebihan) anggaran ke periode berikutnya.';

  @override
  String get rolloverNone => 'Mati';

  @override
  String get rolloverPositiveOnly => 'Hanya sisa';

  @override
  String get rolloverFull => 'Sisa atau kelebihan';

  @override
  String get selectAtLeastTwoCategories => 'Pilih minimal dua kategori';

  @override
  String rolledOverPositive(String amount) {
    return '$amount dibawa dari periode lalu';
  }

  @override
  String rolledOverNegative(String amount) {
    return 'Kelebihan $amount dari periode lalu';
  }

  @override
  String get backupAndRestore => 'Cadangkan & Pulihkan';

  @override
  String get backupAndRestoreSubtitle =>
      'Cadangkan data Anda, atau impor dari file CSV';

  @override
  String get backupSectionTitle => 'Cadangan';

  @override
  String get createBackup => 'Buat cadangan';

  @override
  String get createBackupSubtitle =>
      'Simpan salinan lengkap data Anda untuk dibagikan atau disimpan dengan aman';

  @override
  String get restoreFromBackup => 'Pulihkan dari cadangan';

  @override
  String get restoreFromBackupSubtitle =>
      'Ganti data Anda saat ini dengan cadangan yang pernah disimpan';

  @override
  String get restore => 'Pulihkan';

  @override
  String get backupFailed => 'Gagal membuat cadangan';

  @override
  String get backupIncompatible =>
      'Cadangan ini dibuat dengan versi Finta yang lebih baru dan tidak bisa dipulihkan di sini';

  @override
  String get backupInvalidFile => 'File itu bukan cadangan Finta yang valid';

  @override
  String get restoreBackupTitle => 'Pulihkan cadangan ini?';

  @override
  String restoreBackupConfirm(String date) {
    return 'Ini akan mengganti semua data saat ini dengan cadangan dari $date. Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get restoreFailed => 'Gagal memulihkan cadangan';

  @override
  String get restoreCompleteTitle => 'Cadangan dipulihkan';

  @override
  String get restoreCompleteMessage =>
      'Silakan tutup dan buka kembali Finta untuk menyelesaikan pemuatan data yang dipulihkan.';

  @override
  String get csvImportSectionTitle => 'Impor';

  @override
  String get importCsv => 'Impor dari CSV';

  @override
  String get importCsvSubtitle =>
      'Bawa masuk transaksi dari Finta atau ekspor aplikasi lain';

  @override
  String get csvReadFailed => 'Gagal membaca file CSV itu';

  @override
  String get mapCsvColumns => 'Petakan kolom';

  @override
  String get reviewImport => 'Tinjau impor';

  @override
  String csvRowsFound(int count) {
    return '$count baris ditemukan di file ini';
  }

  @override
  String get csvColumnDate => 'Tanggal';

  @override
  String get csvColumnAmount => 'Jumlah';

  @override
  String get csvColumnType => 'Jenis (pemasukan/pengeluaran)';

  @override
  String get csvColumnCategory => 'Kategori';

  @override
  String get csvColumnMerchant => 'Pedagang';

  @override
  String get csvColumnNote => 'Catatan';

  @override
  String get csvImportToAccount => 'Impor ke akun';

  @override
  String get previewImport => 'Pratinjau impor';

  @override
  String csvImportSummary(int ready, int skipped) {
    return '$ready siap diimpor, $skipped dilewati';
  }

  @override
  String csvRowNumber(int number) {
    return 'Baris $number';
  }

  @override
  String get csvNoErrors => 'Semua baris terlihat baik';

  @override
  String confirmImportCount(int count) {
    return 'Impor $count transaksi';
  }

  @override
  String csvImportedCount(int count) {
    return 'Berhasil mengimpor $count transaksi';
  }

  @override
  String get importFailed => 'Impor gagal';

  @override
  String get importedCategoryName => 'Impor';

  @override
  String get goals => 'Target';

  @override
  String get addGoal => 'Tambah target';

  @override
  String get editGoal => 'Edit target';

  @override
  String get deleteGoal => 'Hapus target';

  @override
  String get goalName => 'Nama target';

  @override
  String get targetAmount => 'Jumlah target';

  @override
  String get targetDateOptional => 'Tanggal target (opsional)';

  @override
  String get noDateSet => 'Belum ada tanggal';

  @override
  String get noGoalsYet => 'Belum ada target';

  @override
  String get noGoalsYetMessage =>
      'Tetapkan target tabungan dan pantau kemajuan Anda';

  @override
  String get contribute => 'Setor';

  @override
  String contributeToGoal(String name) {
    return 'Setor ke $name';
  }

  @override
  String goalProgressAmount(String current, String target) {
    return '$current dari $target';
  }

  @override
  String get goalComplete => 'Target tercapai!';

  @override
  String goalTargetDate(String date) {
    return 'Target: $date';
  }

  @override
  String goalProjectedDate(String date) {
    return 'Perkiraan: $date';
  }

  @override
  String confirmDeleteGoal(String name) {
    return 'Hapus \"$name\"? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String confirmDeleteGoalWithContributions(String name, int count) {
    return '\"$name\" memiliki $count setoran. Menyimpannya akan mengarsipkan target dan saldo dompet Anda tidak berubah. Menghapusnya juga menghapus transaksi tersebut dan mengembalikan uangnya.';
  }

  @override
  String get keepContributions => 'Simpan setoran';

  @override
  String get deleteContributionsToo => 'Hapus setoran juga';

  @override
  String confirmPurgeGoal(String name, int count) {
    return 'Hapus \"$name\" beserta $count setorannya? Transaksi tersebut ikut dihapus dan saldo dompet Anda akan berubah. Tindakan ini tidak bisa dibatalkan.';
  }

  @override
  String get contributions => 'Setoran';

  @override
  String get noContributionsYet => 'Belum ada setoran';

  @override
  String get noContributionsYetMessage =>
      'Setiap setoran yang kamu catat akan muncul di sini beserta dompet asalnya';

  @override
  String get debts => 'Utang Piutang';

  @override
  String get addDebt => 'Tambah catatan';

  @override
  String get editDebt => 'Edit catatan';

  @override
  String get deleteDebt => 'Hapus catatan';

  @override
  String get debtTypeBorrowed => 'Saya meminjam';

  @override
  String get debtTypeLent => 'Saya meminjamkan';

  @override
  String get borrowedFrom => 'Dipinjam dari';

  @override
  String get lentTo => 'Dipinjamkan ke';

  @override
  String get principalAmount => 'Jumlah pokok';

  @override
  String get interestRateOptional => 'Suku bunga (opsional)';

  @override
  String get dueDateOptional => 'Tanggal jatuh tempo (opsional)';

  @override
  String get noDebtsYet => 'Belum ada catatan utang piutang';

  @override
  String get noDebtsYetMessage =>
      'Catat uang yang Anda pinjamkan atau pinjam dan catat pembayarannya dari waktu ke waktu';

  @override
  String get owedToYou => 'Piutang Anda';

  @override
  String get youOwe => 'Utang Anda';

  @override
  String get debtSettled => 'Lunas';

  @override
  String debtOutstandingOfPrincipal(String outstanding, String principal) {
    return '$outstanding dari $principal tersisa';
  }

  @override
  String debtDueDate(String date) {
    return 'Jatuh tempo $date';
  }

  @override
  String get logRepaymentAction => 'Catat pembayaran';

  @override
  String logRepayment(String name) {
    return 'Catat pembayaran untuk $name';
  }

  @override
  String confirmDeleteDebt(String name) {
    return 'Hapus \"$name\"? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String confirmDeleteDebtWithRepayments(String name, int count) {
    return '\"$name\" memiliki $count pembayaran. Menyimpannya akan mengarsipkan catatan ini dan saldo dompet Anda tidak berubah. Menghapusnya juga menghapus transaksi tersebut dan mengembalikan uangnya.';
  }

  @override
  String get keepRepayments => 'Simpan pembayaran';

  @override
  String get deleteRepaymentsToo => 'Hapus pembayaran juga';

  @override
  String confirmPurgeDebt(String name, int count) {
    return 'Hapus \"$name\" beserta $count pembayarannya? Transaksi tersebut ikut dihapus dan saldo dompet Anda akan berubah. Tindakan ini tidak bisa dibatalkan.';
  }

  @override
  String get repayments => 'Pembayaran';

  @override
  String get noRepaymentsYet => 'Belum ada pembayaran';

  @override
  String get noRepaymentsYetMessage =>
      'Setiap pembayaran yang kamu catat akan muncul di sini beserta dompet yang dipakai';

  @override
  String get payoffCalculator => 'Kalkulator pelunasan';

  @override
  String payoffOutstandingLabel(String amount) {
    return 'Sisa: $amount';
  }

  @override
  String get monthlyPayment => 'Pembayaran bulanan';

  @override
  String get payoffNeverAtThisRate =>
      'Pembayaran ini tidak menutupi bunga — saldo tidak akan pernah lunas';

  @override
  String payoffMonthsEstimate(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Lunas dalam $months bulan',
      one: 'Lunas dalam 1 bulan',
    );
    return '$_temp0';
  }

  @override
  String get goalsAndDebts => 'Target & Utang Piutang';

  @override
  String netDebtSummary(String owed, String owe) {
    return '$owed piutang Anda · $owe utang Anda';
  }

  @override
  String get markAsSubscription => 'Lacak sebagai langganan?';

  @override
  String get markAsSubscriptionHelp =>
      'Langganan muncul di layar Langganan beserta total biayanya, dan bisa mengingatkan Anda sebelum diperpanjang.';

  @override
  String get subscriptions => 'Langganan';

  @override
  String get noSubscriptionsTitle => 'Belum ada langganan yang dilacak';

  @override
  String get noSubscriptionsSubtitle =>
      'Tandai transaksi berulang sebagai langganan untuk melacak biayanya dan mendapat pengingat perpanjangan';

  @override
  String get subscriptionSuggestions => 'Saran';

  @override
  String subscriptionSuggestionSubtitle(String amount, int count) {
    return '$amount/bulan · terlihat $count kali';
  }

  @override
  String get yourSubscriptions => 'Langganan Anda';

  @override
  String get perMonth => 'Per bulan';

  @override
  String get perYear => 'Per tahun';

  @override
  String get dismiss => 'Abaikan';

  @override
  String get overdue => 'Terlambat';

  @override
  String get pause => 'Jeda';

  @override
  String get resume => 'Lanjutkan';

  @override
  String get setReminder => 'Atur pengingat';

  @override
  String get notASubscription => 'Bukan langganan';

  @override
  String get reminderOff => 'Tanpa pengingat';

  @override
  String reminderDaysBeforeOption(int days) {
    return '$days hari sebelumnya';
  }

  @override
  String get trends => 'Tren';

  @override
  String get cashflow => 'Arus Kas';

  @override
  String netCashflowOverMonths(int months, String amount) {
    return 'Bersih selama $months bulan terakhir: $amount';
  }

  @override
  String get categoryTrend => 'Tren kategori';

  @override
  String categoryAboveAverage(String percent, int months) {
    return '$percent% di atas rata-rata $months bulan Anda';
  }

  @override
  String categoryBelowAverage(String percent, int months) {
    return '$percent% di bawah rata-rata $months bulan Anda';
  }

  @override
  String get spendingHeatmap => 'Peta panas pengeluaran';

  @override
  String get topMerchants => 'Pedagang teratas';

  @override
  String get noMerchantsForThisPeriod =>
      'Belum ada pedagang tercatat pada periode ini. Isi kolom Pedagang pada transaksi agar muncul di sini.';

  @override
  String timesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kali',
      one: '1 kali',
    );
    return '$_temp0';
  }

  @override
  String get fillOutFormFirst =>
      'Isi jumlah, kategori, dan akun terlebih dahulu';

  @override
  String get saveAsTemplate => 'Simpan sebagai templat';

  @override
  String get saveAsTemplateHelp =>
      'Simpan transaksi ini sebagai templat sekali klik yang dapat digunakan kembali';

  @override
  String get templateName => 'Nama templat';

  @override
  String templateSaved(String name) {
    return 'Menyimpan \"$name\" sebagai templat';
  }

  @override
  String get deleteTemplate => 'Hapus templat';

  @override
  String confirmDeleteTemplate(String name) {
    return 'Hapus templat \"$name\"? Ini tidak akan memengaruhi transaksi sebelumnya.';
  }

  @override
  String get invalidExpression => 'Bukan ekspresi yang valid';

  @override
  String get done => 'Selesai';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dipilih',
      one: '1 dipilih',
    );
    return '$_temp0';
  }

  @override
  String get duplicate => 'Duplikat';

  @override
  String get recategorize => 'Ubah kategori';

  @override
  String confirmBulkDelete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hapus $count transaksi ini?',
      one: 'Hapus transaksi ini?',
    );
    return '$_temp0';
  }

  @override
  String get cannotDuplicateTransfers =>
      'Transfer tidak dapat diduplikasi — pilih transaksi biasa sebagai gantinya';

  @override
  String get cannotRecategorizeTransfers =>
      'Transfer tidak dapat diubah kategorinya — pilih transaksi biasa sebagai gantinya';

  @override
  String get selectSameTypeToRecategorize =>
      'Pilih hanya transaksi pemasukan atau hanya pengeluaran untuk diubah kategorinya bersamaan';

  @override
  String get unusualAmountTitle => 'Jumlah tidak biasa';

  @override
  String unusualAmountMessage(String amount, String category, String typical) {
    return '$amount tidak biasa untuk $category — biasanya sekitar $typical. Lanjutkan?';
  }

  @override
  String get continueAnyway => 'Tetap lanjutkan';

  @override
  String get smartInsights => 'Wawasan Cerdas';

  @override
  String get financialHealthScore => 'Skor kesehatan finansial';

  @override
  String get outOfHundred => 'dari 100';

  @override
  String get healthScoreSavings => 'Tingkat tabungan';

  @override
  String get healthScoreBudget => 'Kepatuhan anggaran';

  @override
  String get healthScoreStability => 'Stabilitas pemasukan';

  @override
  String get spendingInsightsTitle => 'Wawasan';

  @override
  String get noInsightsYet => 'Belum ada perubahan berarti dari periode lalu';

  @override
  String get unusualActivity => 'Aktivitas tidak biasa';

  @override
  String get noUnusualActivity =>
      'Tidak ada yang tidak biasa dalam 30 hari terakhir';

  @override
  String insightFastestGrowingTitle(String category) {
    return 'Paling cepat naik: $category';
  }

  @override
  String insightFastestGrowingBody(String percent) {
    return 'Naik $percent% dari periode gaji lalu';
  }

  @override
  String insightSpendingIncreasedTitle(String category) {
    return '$category naik';
  }

  @override
  String insightSpendingIncreasedBody(String percent) {
    return '$percent% lebih tinggi dari periode lalu';
  }

  @override
  String insightSpendingDecreasedTitle(String category) {
    return '$category turun';
  }

  @override
  String insightSpendingDecreasedBody(String percent) {
    return '$percent% lebih rendah dari periode lalu';
  }

  @override
  String get periodRecap => 'Rekap Periode';

  @override
  String yourPeriodRecapTitle(String range) {
    return '$range Anda';
  }

  @override
  String periodInProgress(int day, int total) {
    return 'Sedang berjalan · hari ke-$day dari $total';
  }

  @override
  String get topCategories => 'Kategori teratas';

  @override
  String get savingsRate => 'Tingkat tabungan';

  @override
  String get systemDefault => 'Default Sistem';

  @override
  String get selectPayday => 'Pilih Tanggal Gajian';

  @override
  String get errorFailedToExport => 'Gagal mengekspor data';

  @override
  String get selectIcon => 'Pilih Ikon';

  @override
  String get continueLabel => 'Lanjutkan';

  @override
  String get errorFailedToLoadData => 'Gagal memuat data';

  @override
  String confirmDeleteTransactionMessage(String type, String amount) {
    return 'Apakah Anda yakin ingin menghapus $type sebesar $amount ini?';
  }

  @override
  String paydayDayLabel(int day) {
    return 'Tanggal $day';
  }
}
