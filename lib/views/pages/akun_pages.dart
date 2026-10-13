import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../viewmodels/akun_view_model.dart';
import '../../viewmodels/app_deps.dart';
import '../theme.dart';
import '../widgets/common.dart';

AkunViewModel _create(BuildContext context) {
  final deps = context.read<AppDeps>();
  return AkunViewModel(session: deps.session, sales: deps.sales, theme: deps.theme, prefs: deps.prefs, toast: deps.toast, confirm: ({required title, required message}) => deps.dialog.confirm(title: title, message: message, confirmText: 'Ya', cancelText: 'Batal', danger: true));
}

class AkunPage extends StatelessWidget {
  const AkunPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: _create, child: const _AkunView());
}

class _AkunView extends StatelessWidget {
  const _AkunView();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vm = context.watch<AkunViewModel>();
    final user = vm.session.user;
    final outbox = vm.outbox;
    final failed = outbox.entries.where((e) => e.isFailed).toList();

    return PageScroll(children: [
      const PageHeader(greeting: 'Akun', title: 'Informasi Akun', subtitle: 'Detail akun yang sedang login di perangkat ini.'),
      SectionCard(
        child: Column(children: [
          Row(children: [
            CircleAvatar(radius: 28, backgroundColor: p.primary, child: Text(user?.avatar ?? '?', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user?.name ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text('${user?.isAdmin == true ? 'Kepala Cashier' : 'Kasir'} · @${user?.username ?? '-'}', style: TextStyle(color: p.textSecondary))])),
          ]),
          const SizedBox(height: 10),
          InfoRow('Role', user?.isAdmin == true ? 'Kepala Cashier' : 'Kasir'),
          InfoRow('Cabang', vm.session.currentTenant.name),
          InfoRow('Login terakhir', user == null ? '-' : formatDateTime(user.loginTime), last: true),
        ]),
      ),
      SectionCard(
        title: 'Penjualan Offline',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InfoRow('Menunggu dikirim', '${outbox.pending}'),
          InfoRow('Ditolak database', '${outbox.failed}', last: true),
          if (outbox.pending > 0) Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton(onPressed: vm.flushNow, child: const Text('Kirim Sekarang'))),
          for (final e in failed)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: p.danger.withValues(alpha: 0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${formatRupiah(e.expectedTotal)} · ${formatDateTime(e.at)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(e.error ?? 'Ditolak database.', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                const SizedBox(height: 8),
                Row(children: [OutlinedButton(onPressed: () => vm.retry(e), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), child: const Text('Coba lagi')), const SizedBox(width: 8), OutlinedButton(onPressed: () => vm.discard(e), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), child: const Text('Buang'))]),
              ]),
            ),
          Padding(padding: const EdgeInsets.only(top: 12), child: Text('Penjualan yang dibuat saat offline tersimpan di perangkat ini sampai terkirim. Jangan menghapus data aplikasi sebelum antrean kosong.', style: TextStyle(fontSize: 12, color: p.textMuted))),
        ]),
      ),
    ]);
  }
}

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: _create, child: const _PengaturanView());
}

class _PengaturanView extends StatelessWidget {
  const _PengaturanView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AkunViewModel>();
    return ListenableBuilder(
      listenable: vm.theme,
      builder: (context, _) => PageScroll(children: [
        const PageHeader(greeting: 'Preferensi', title: 'Pengaturan', subtitle: 'Sesuaikan tampilan dan perilaku aplikasi.'),
        SectionCard(
          title: 'Tema Tampilan',
          child: SegmentTabs<ThemeMode>(value: vm.theme.mode, options: const {ThemeMode.system: 'Sistem', ThemeMode.light: 'Terang', ThemeMode.dark: 'Gelap'}, onChanged: vm.theme.set),
        ),
        SectionCard(
          title: 'Kamera Scan Barcode',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentTabs<bool>(value: vm.scanFront, options: const {false: 'Belakang', true: 'Depan'}, onChanged: vm.setScanFront),
            const SizedBox(height: 8),
            Text('Dipakai di Stok Awal dan Transaksi. Bisa juga diganti langsung di layar scan.', style: TextStyle(fontSize: 12, color: context.pal.textMuted)),
          ]),
        ),
        SectionCard(
          title: 'Struk',
          child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Cetak otomatis setelah pembayaran', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Dialog cetak sistem dibuka setiap pembayaran berhasil.'), value: vm.autoPrint, onChanged: vm.setAutoPrint),
        ),
        SectionCard(title: 'Tentang', child: Column(children: [InfoRow('Versi aplikasi', vm.version), InfoRow('Cabang aktif', vm.session.currentTenant.name, last: true)])),
      ]),
    );
  }
}
