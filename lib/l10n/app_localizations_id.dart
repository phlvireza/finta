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
  String get paused => 'Jeda';

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
  String get quarter => 'Kuartal';

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
  String safeToSpendPerDay(String amount, int days) {
    return 'Aman dibelanjakan: $amount/hari selama $days hari lagi';
  }

  @override
  String percentOfIncomeSpent(String percent) {
    return '$percent dari pemasukan terpakai';
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
  String get budgetPerformance => 'Kinerja anggaran';

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
}
