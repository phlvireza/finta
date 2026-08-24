import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isIndonesian = Localizations.localeOf(context).languageCode == 'id';
    final title = isIndonesian ? 'Kebijakan Privasi' : 'Privacy Policy';
    final sections = isIndonesian ? _indonesianSections : _englishSections;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text(
            isIndonesian
                ? 'Terakhir diperbarui: 24 Agustus 2026'
                : 'Last updated: August 24, 2026',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          for (final section in sections) ...[
            Text(section.$1, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(section.$2, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

const _englishSections = <(String, String)>[
  (
    'Overview',
    'Squirio is published by Japandi Dev. It is a local-first personal finance app designed to work without an account, advertising, analytics, or a remote server.',
  ),
  (
    'Information stored on your device',
    'Transactions, accounts, budgets, goals, debts, categories, recurring items, preferences, and related financial calculations are stored locally in the app’s private storage. Japandi Dev does not receive this information.',
  ),
  (
    'Collection and sharing',
    'Squirio does not collect, sell, or share personal or financial information. The app does not contain advertising or analytics SDKs and does not require an internet connection.',
  ),
  (
    'Backups and exports',
    'When you create a backup or CSV export, Squirio gives the file to the operating system share or file picker that you choose. The destination service’s privacy terms apply after you send or save that file. Japandi Dev does not receive a copy.',
  ),
  (
    'Notifications',
    'If you enable a reminder, Squirio requests notification permission and schedules the reminder locally on your device. Reminder information is not sent to Japandi Dev.',
  ),
  (
    'Retention and deletion',
    'App data remains on your device until you delete it in the app, clear the app’s storage, or uninstall the app. Backups and exported files must be deleted separately from the location where you saved them.',
  ),
  (
    'Children',
    'Squirio is not directed to children under 13 and does not knowingly collect information from children.',
  ),
  (
    'Contact and changes',
    'The privacy contact address will be shown on Squirio’s store listing before public release. Material changes to this policy will be reflected in the app and on the public privacy-policy page.',
  ),
];

const _indonesianSections = <(String, String)>[
  (
    'Ringkasan',
    'Squirio diterbitkan oleh Japandi Dev. Squirio adalah aplikasi keuangan pribadi yang mengutamakan penyimpanan lokal dan bekerja tanpa akun, iklan, analitik, atau server jarak jauh.',
  ),
  (
    'Informasi yang tersimpan di perangkat',
    'Transaksi, akun, anggaran, target, utang, kategori, item berulang, preferensi, dan perhitungan keuangan terkait disimpan secara lokal di penyimpanan privat aplikasi. Japandi Dev tidak menerima informasi ini.',
  ),
  (
    'Pengumpulan dan pembagian',
    'Squirio tidak mengumpulkan, menjual, atau membagikan informasi pribadi maupun keuangan. Aplikasi tidak memuat SDK iklan atau analitik dan tidak memerlukan koneksi internet.',
  ),
  (
    'Cadangan dan ekspor',
    'Saat Anda membuat cadangan atau ekspor CSV, Squirio menyerahkan berkas tersebut ke lembar berbagi atau pemilih berkas sistem operasi yang Anda pilih. Ketentuan privasi layanan tujuan berlaku setelah Anda mengirim atau menyimpan berkas. Japandi Dev tidak menerima salinannya.',
  ),
  (
    'Notifikasi',
    'Jika Anda mengaktifkan pengingat, Squirio meminta izin notifikasi dan menjadwalkannya secara lokal di perangkat. Informasi pengingat tidak dikirim ke Japandi Dev.',
  ),
  (
    'Penyimpanan dan penghapusan',
    'Data aplikasi tetap berada di perangkat sampai Anda menghapusnya di aplikasi, membersihkan penyimpanan aplikasi, atau menghapus instalasi. Cadangan dan berkas ekspor harus dihapus terpisah dari lokasi tempat Anda menyimpannya.',
  ),
  (
    'Anak-anak',
    'Squirio tidak ditujukan untuk anak di bawah 13 tahun dan tidak dengan sengaja mengumpulkan informasi dari anak-anak.',
  ),
  (
    'Kontak dan perubahan',
    'Alamat kontak privasi akan ditampilkan di halaman toko Squirio sebelum rilis publik. Perubahan penting pada kebijakan ini akan ditampilkan di aplikasi dan halaman kebijakan privasi publik.',
  ),
];
